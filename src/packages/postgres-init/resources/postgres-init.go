package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

type Config struct {
	Host        string
	SuperUser   string
	SuperPass   string
	User        string
	UserPass    string
	DBName      string
	Port        string
	UserFlags   string
	InitSQLDir  string
}

func main() {
	cfg := loadConfig()
	
	ctx := context.Background()
	pool := connectPostgres(ctx, cfg)
	defer pool.Close()

	waitForPostgres(ctx, pool, cfg)

	// Check/create user
	if err := createUser(ctx, pool, cfg); err != nil {
		log.Fatal(err)
	}

	// Update user password
	if err := updateUserPassword(ctx, pool, cfg); err != nil {
		log.Fatal(err)
	}

	// Process databases
	if err := processDatabases(ctx, pool, cfg); err != nil {
		log.Fatal(err)
	}

	colorPrint("Database initialization completed successfully", "green")
}

func loadConfig() Config {
	cfg := Config{
		Host:       os.Getenv("INIT_POSTGRES_HOST"),
		SuperUser:  getEnvWithDefault("INIT_POSTGRES_SUPER_USER", "postgres"),
		SuperPass:  os.Getenv("INIT_POSTGRES_SUPER_PASS"),
		User:       os.Getenv("INIT_POSTGRES_USER"),
		UserPass:   os.Getenv("INIT_POSTGRES_PASS"),
		DBName:     os.Getenv("INIT_POSTGRES_DBNAME"),
		Port:       getEnvWithDefault("INIT_POSTGRES_PORT", "5432"),
		UserFlags:  os.Getenv("INIT_POSTGRES_USER_FLAGS"),
		InitSQLDir: "/initdb",
	}

	// Validate required config
	if cfg.Host == "" || cfg.SuperPass == "" || cfg.User == "" || cfg.UserPass == "" || cfg.DBName == "" {
		colorPrint("Invalid configuration - missing a required environment variable", "red")
		if cfg.Host == "" {
			colorPrint("INIT_POSTGRES_HOST: unset", "red")
		}
		if cfg.SuperPass == "" {
			colorPrint("INIT_POSTGRES_SUPER_PASS: unset", "red")
		}
		if cfg.User == "" {
			colorPrint("INIT_POSTGRES_USER: unset", "red")
		}
		if cfg.UserPass == "" {
			colorPrint("INIT_POSTGRES_PASS: unset", "red")
		}
		if cfg.DBName == "" {
			colorPrint("INIT_POSTGRES_DBNAME: unset", "red")
		}
		os.Exit(1)
	}

	return cfg
}

func getEnvWithDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func connectPostgres(ctx context.Context, cfg Config) *pgxpool.Pool {
	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/postgres?sslmode=disable",
		cfg.SuperUser, cfg.SuperPass, cfg.Host, cfg.Port)

	config, err := pgxpool.ParseConfig(connStr)
	if err != nil {
		log.Fatalf("Unable to parse connection config: %v", err)
	}

	// Configure pool settings
	config.MaxConns = 5
	config.MinConns = 1
	config.HealthCheckPeriod = time.Minute
	config.MaxConnLifetime = time.Hour

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}

	return pool
}

func waitForPostgres(ctx context.Context, pool *pgxpool.Pool, cfg Config) {
	start := time.Now()
	timeout := 30 * time.Second
	
	for {
		if time.Since(start) > timeout {
			log.Fatal("Timeout waiting for PostgreSQL to become ready")
		}

		err := pool.Ping(ctx)
		if err == nil {
			colorPrint(fmt.Sprintf("Connected to PostgreSQL at %s:%s", cfg.Host, cfg.Port), "green")
			break
		}

		colorPrint(fmt.Sprintf("Waiting for Host '%s' on port '%s'...", cfg.Host, cfg.Port), "yellow")
		time.Sleep(1 * time.Second)
	}
}

func createUser(ctx context.Context, pool *pgxpool.Pool, cfg Config) error {
	var exists bool
	err := pool.QueryRow(ctx, 
		"SELECT 1 FROM pg_roles WHERE rolname = $1", cfg.User).Scan(&exists)
	
	if err != nil && !strings.Contains(err.Error(), "no rows in result set") {
		return fmt.Errorf("failed to check user existence: %w", err)
	}

	if !exists {
		colorPrint(fmt.Sprintf("Create User %s...", cfg.User), "green")
		
		// Start building the CREATE ROLE statement
		sql := fmt.Sprintf("CREATE ROLE \"%s\"", cfg.User)
		
		// Add password
		sql += fmt.Sprintf(" LOGIN PASSWORD '%s'", cfg.UserPass)
		
		// Add flags if specified
		if cfg.UserFlags != "" {
			flags := strings.Fields(cfg.UserFlags)
			for _, flag := range flags {
				switch flag {
				case "--createdb":
					sql += " CREATEDB"
				case "--createrole":
					sql += " CREATEROLE"
				case "--inherit":
					sql += " INHERIT"
				case "--login":
					// Already added LOGIN above
				case "--no-login":
					sql += " NOLOGIN"
				case "--replication":
					sql += " REPLICATION"
				case "--superuser":
					sql += " SUPERUSER"
				case "--no-superuser":
					sql += " NOSUPERUSER"
				default:
					if strings.HasPrefix(flag, "--") {
						log.Printf("Warning: Unsupported user flag: %s", flag)
					}
				}
			}
		}
		
		_, err = pool.Exec(ctx, sql)
		if err != nil {
			return fmt.Errorf("failed to create user: %w", err)
		}
	}
	return nil
}

func updateUserPassword(ctx context.Context, pool *pgxpool.Pool, cfg Config) error {
	colorPrint(fmt.Sprintf("Update password for user %s...", cfg.User), "green")
	_, err := pool.Exec(ctx, 
		"ALTER USER $1 WITH ENCRYPTED PASSWORD $2", cfg.User, cfg.UserPass)
	return err
}

func processDatabases(ctx context.Context, pool *pgxpool.Pool, cfg Config) error {
	for _, dbname := range strings.Fields(cfg.DBName) {
		var exists bool
		err := pool.QueryRow(ctx,
			"SELECT 1 FROM pg_database WHERE datname = $1", dbname).Scan(&exists)
		
		if err != nil && !strings.Contains(err.Error(), "no rows in result set") {
			return fmt.Errorf("failed to check database existence: %w", err)
		}

		if !exists {
			colorPrint(fmt.Sprintf("Create Database %s...", dbname), "green")
			_, err = pool.Exec(ctx,
				fmt.Sprintf("CREATE DATABASE \"%s\" OWNER \"%s\"", dbname, cfg.User))
			if err != nil {
				return fmt.Errorf("failed to create database: %w", err)
			}

			// Initialize database if SQL file exists
			initFile := fmt.Sprintf("%s/%s.sql", cfg.InitSQLDir, dbname)
			if _, err := os.Stat(initFile); err == nil {
				colorPrint("Initialize Database...", "green")
				sqlContent, err := os.ReadFile(initFile)
				if err != nil {
					return fmt.Errorf("failed to read SQL file: %w", err)
				}
				
				// Connect to the new database to run the init script
				dbConfig, err := pgxpool.ParseConfig(fmt.Sprintf(
					"postgres://%s:%s@%s:%s/%s?sslmode=disable",
					cfg.SuperUser, cfg.SuperPass, cfg.Host, cfg.Port, dbname))
				if err != nil {
					return fmt.Errorf("failed to parse db config: %w", err)
				}
				
				dbPool, err := pgxpool.NewWithConfig(ctx, dbConfig)
				if err != nil {
					return fmt.Errorf("failed to connect to database: %w", err)
				}
				defer dbPool.Close()
				
				_, err = dbPool.Exec(ctx, string(sqlContent))
				if err != nil {
					return fmt.Errorf("failed to execute init script: %w", err)
				}
			}
		}

		colorPrint("Update User Privileges on Database...", "green")
		_, err = pool.Exec(ctx,
			fmt.Sprintf("GRANT ALL PRIVILEGES ON DATABASE \"%s\" TO \"%s\"", 
				dbname, cfg.User))
		if err != nil {
			return fmt.Errorf("failed to grant privileges: %w", err)
		}
	}
	return nil
}

func colorPrint(text, color string) {
	var colorCode string
	switch color {
	case "red":
		colorCode = "\033[31m"
	case "green":
		colorCode = "\033[32m"
	case "yellow":
		colorCode = "\033[33m"
	default:
		colorCode = "\033[0m"
	}
	fmt.Printf("%s%s\033[0m\n", colorCode, text)
}

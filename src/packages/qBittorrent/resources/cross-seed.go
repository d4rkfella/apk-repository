package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds the configuration variables
type Config struct {
	CrossSeedEnabled      bool
	CrossSeedURL          string
	CrossSeedAPIKey       string
	CrossSeedSleepInterval int
	PushoverEnabled       bool
	PushoverUserKey       string
	PushoverToken         string
}

// ReleaseInfo holds the release information from qBittorrent
type ReleaseInfo struct {
	Name     string
	InfoHash string
	Category string
	Size     int64
	Indexer  string
	Type     string
}

var config Config

func init() {
	// Initialize configuration from environment variables
	config.CrossSeedEnabled = getEnvBool("CROSS_SEED_ENABLED", false)
	config.CrossSeedURL = getEnv("CROSS_SEED_URL", "required")
	config.CrossSeedAPIKey = getEnv("CROSS_SEED_API_KEY", "required")
	config.CrossSeedSleepInterval = getEnvInt("CROSS_SEED_SLEEP_INTERVAL", 30)
	config.PushoverEnabled = getEnvBool("PUSHOVER_ENABLED", false)
	config.PushoverUserKey = getEnv("PUSHOVER_USER_KEY", "required")
	config.PushoverToken = getEnv("PUSHOVER_TOKEN", "required")
}

func main() {
	if len(os.Args) != 6 {
		fmt.Fprintln(os.Stderr, "Usage: <program> <release_name> <info_hash> <category> <size> <indexer>")
		os.Exit(1)
	}

	release := ReleaseInfo{
		Name:     os.Args[1],
		InfoHash: os.Args[2],
		Category: os.Args[3],
		Size:     parseSize(os.Args[4]),
		Indexer:  os.Args[5],
		Type:     "Torrent",
	}

	if config.PushoverEnabled {
		if err := sendPushoverNotification(release); err != nil {
			fmt.Fprintf(os.Stderr, "Error sending Pushover notification: %v\n", err)
		}
	}

	if config.CrossSeedEnabled {
		if err := searchCrossSeed(release); err != nil {
			fmt.Fprintf(os.Stderr, "Error searching CrossSeed: %v\n", err)
		}
	}
}

func getEnv(key, defaultValue string) string {
	value, exists := os.LookupEnv(key)
	if !exists {
		return defaultValue
	}
	return value
}

func getEnvBool(key string, defaultValue bool) bool {
	value, exists := os.LookupEnv(key)
	if !exists {
		return defaultValue
	}
	return value == "true"
}

func getEnvInt(key string, defaultValue int) int {
	value, exists := os.LookupEnv(key)
	if !exists {
		return defaultValue
	}
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return intValue
}

func parseSize(sizeStr string) int64 {
	size, err := strconv.ParseInt(sizeStr, 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing size: %v\n", err)
		os.Exit(1)
	}
	return size
}

func sendPushoverNotification(release ReleaseInfo) error {
	u, err := url.Parse(release.Indexer)
	if err != nil {
		return fmt.Errorf("error parsing indexer URL: %v", err)
	}

	message := fmt.Sprintf("<b>%s</b><small>\n<b>Category:</b> %s</small><small>\n<b>Indexer:</b> %s</small><small>\n<b>Size:</b> %s</small>",
		strings.TrimSuffix(release.Name, ".torrent"),
		release.Category,
		u.Hostname(),
		formatSize(release.Size),
	)

	data := map[string]string{
		"token":     config.PushoverToken,
		"user":      config.PushoverUserKey,
		"title":     fmt.Sprintf("%s Downloaded", release.Type),
		"message":   message,
		"priority":  "-2",
		"html":      "1",
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("error marshalling JSON: %v", err)
	}

	resp, err := http.Post("https://api.pushover.net/1/messages.json", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("error sending Pushover notification: %v", err)
	}
	defer resp.Body.Close()

	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Printf("Pushover notification returned with HTTP status code %d and payload: %s\n", resp.StatusCode, string(body))
	return nil
}

func searchCrossSeed(release ReleaseInfo) error {
	data := url.Values{}
	data.Set("infoHash", release.InfoHash)
	data.Set("includeSingleEpisodes", "true")

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/api/webhook", config.CrossSeedURL), strings.NewReader(data.Encode()))
	if err != nil {
		return fmt.Errorf("error creating CrossSeed request: %v", err)
	}
	req.Header.Set("X-Api-Key", config.CrossSeedAPIKey)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error sending CrossSeed request: %v", err)
	}
	defer resp.Body.Close()

	fmt.Printf("Cross-seed search returned with HTTP status code %d and path %s\n", resp.StatusCode, release.Name)
	time.Sleep(time.Duration(config.CrossSeedSleepInterval) * time.Second)
	return nil
}

func formatSize(size int64) string {
	const unit = 1024
	if size < unit {
		return fmt.Sprintf("%d B", size)
	}
	div, exp := int64(unit), 0
	for n := size / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.2f %ciB", float64(size)/float64(div), "KMGTPE"[exp])
}

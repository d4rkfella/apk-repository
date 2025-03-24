package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	return err
}

func main() {
	configFile := "/config/qBittorrent/qBittorrent.conf"
	logFile := "/config/qBittorrent/logs/qbittorrent.log"

	os.Setenv("QBT_WEBUI_PORT", os.Getenv("QBITTORRENT__PORT"))
	os.Setenv("QBT_TORRENTING_PORT", os.Getenv("QBITTORRENT__BT_PORT"))

	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		fmt.Println("Copying over default configuration ...")
		err := os.MkdirAll(filepath.Dir(configFile), os.ModePerm)
		if err != nil {
			fmt.Printf("Error creating config directory: %v\n", err)
			return
		}
		err = copyFile("/app/qBittorrent.conf", configFile)
		if err != nil {
			fmt.Printf("Error copying config file: %v\n", err)
			return
		}
	}

	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		err := os.MkdirAll(filepath.Dir(logFile), os.ModePerm)
		if err != nil {
			fmt.Printf("Error creating log directory: %v\n", err)
			return
		}
		err = os.Symlink("/proc/self/fd/1", logFile)
		if err != nil {
			fmt.Printf("Error creating symlink for log file: %v\n", err)
			return
		}
	}

	cmd := exec.Command("/usr/bin/qbittorrent-nox")
	cmd.Args = append(cmd.Args, os.Args[1:]...) // Pass any command-line arguments
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	if err != nil {
		fmt.Printf("Error running qBittorrent: %v\n", err)
	}
}

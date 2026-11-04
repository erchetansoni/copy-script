//go:build !windows

package main

func isDoubleClickedOnWindows() bool {
	return false
}

func pauseIfDoubleClicked() {
	// No-op on POSIX/Linux
}


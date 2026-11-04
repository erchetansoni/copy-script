//go:build windows

package main

import (
	"fmt"
	"os"
	"syscall"
	"unsafe"
)

func isDoubleClickedOnWindows() bool {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	proc := kernel32.NewProc("GetConsoleProcessList")
	var pids [2]uint32
	r, _, _ := proc.Call(uintptr(unsafe.Pointer(&pids[0])), 2)
	return r == 1
}

func pauseIfDoubleClicked() {
	if isDoubleClickedOnWindows() {
		fmt.Println("\nPress Enter to exit...")
		var b [1]byte
		_, _ = os.Stdin.Read(b[:])
	}
}


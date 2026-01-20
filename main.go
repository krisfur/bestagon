package main

import (
	"fmt"
	"runtime"

	rl "github.com/gen2brain/raylib-go/raylib"
	steamworks "github.com/hajimehoshi/go-steamworks"
)

func main() {
	// ---------------------------------------------------------
	// 1. Initialize Steamworks
	// ---------------------------------------------------------
	// Lock the OS thread. Steam callbacks and Raylib both prefer the main thread.
	runtime.LockOSThread()

	// Initialize Steam. If this fails, the user likely doesn't have Steam running,
	// or the steam_appid.txt file is missing.
	if err := steamworks.Init(); err != nil {
		panic(fmt.Sprintf("Steamworks failed to initialize: %v\nMake sure Steam is running and steam_appid.txt is present.", err))
	}

	fmt.Println("Steamworks initialized successfully!")

	// Check if the user owns the game (Anti-piracy check)
	// if steamworks.RestartAppIfNecessary(480) { return }

	// ---------------------------------------------------------
	// 2. Initialize Raylib
	// ---------------------------------------------------------
	rl.InitWindow(800, 450, "Go + Raylib + Steam!")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// ---------------------------------------------------------
	// 3. Game Loop
	// ---------------------------------------------------------
	for !rl.WindowShouldClose() {
		// VITAL: Process Steam callbacks (achievements, overlay, inputs)
		// This must run every frame!
		steamworks.RunCallbacks()

		rl.BeginDrawing()
		rl.ClearBackground(rl.RayWhite)

		rl.DrawText("Congrats! You are running Go on Steam.", 190, 200, 20, rl.LightGray)

		// Let's print the current language via Steam to prove it works
		lang := steamworks.SteamApps().GetCurrentGameLanguage()
		rl.DrawText(fmt.Sprintf("Steam Language: %s", lang), 190, 230, 20, rl.Gray)

		rl.EndDrawing()
	}
}

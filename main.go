package main

import (
	"fmt"
	"math"
	"runtime"

	rl "github.com/gen2brain/raylib-go/raylib"
	steamworks "github.com/hajimehoshi/go-steamworks"
)

type Vector2 struct {
	X, Y float32
}

type Player struct {
	Position Vector2
	Velocity Vector2
	Speed    float32
	Radius   float32
}

type Star struct {
	Position Vector2
	Radius   float32
	Speed    float32
}

func (p *Player) Update() {
	// Reset velocity
	p.Velocity.X = 0
	p.Velocity.Y = 0

	// Handle input
	if rl.IsKeyDown(rl.KeyW) || rl.IsKeyDown(rl.KeyUp) {
		p.Velocity.Y -= p.Speed
	}
	if rl.IsKeyDown(rl.KeyS) || rl.IsKeyDown(rl.KeyDown) {
		p.Velocity.Y += p.Speed
	}
	if rl.IsKeyDown(rl.KeyA) || rl.IsKeyDown(rl.KeyLeft) {
		p.Velocity.X -= p.Speed
	}
	if rl.IsKeyDown(rl.KeyD) || rl.IsKeyDown(rl.KeyRight) {
		p.Velocity.X += p.Speed
	}

	// Update position
	p.Position.X += p.Velocity.X
	p.Position.Y += p.Velocity.Y

	// Keep player within screen bounds
	screenWidth := float32(rl.GetScreenWidth())
	screenHeight := float32(rl.GetScreenHeight())

	if p.Position.X-p.Radius < 0 {
		p.Position.X = p.Radius
	}
	if p.Position.X+p.Radius > screenWidth {
		p.Position.X = screenWidth - p.Radius
	}
	if p.Position.Y-p.Radius < 0 {
		p.Position.Y = p.Radius
	}
	if p.Position.Y+p.Radius > screenHeight {
		p.Position.Y = screenHeight - p.Radius
	}
}

func (s *Star) Update(playerPos Vector2) {
	// Target position is to the right of the player
	targetX := playerPos.X + 40
	targetY := playerPos.Y

	// Smoothly lerp towards target for springy, bouncy movement
	s.Position.X += (targetX - s.Position.X) * s.Speed
	s.Position.Y += (targetY - s.Position.Y) * s.Speed
}

func drawHexagon(centerX, centerY, radius float32, color rl.Color) {
	// Draw a hexagon with 6 vertices
	numSides := 6
	for i := 0; i < numSides; i++ {
		angle1 := float32(i) * 2 * math.Pi / float32(numSides)
		angle2 := float32(i+1) * 2 * math.Pi / float32(numSides)

		x1 := centerX + radius*float32(math.Cos(float64(angle1)))
		y1 := centerY + radius*float32(math.Sin(float64(angle1)))
		x2 := centerX + radius*float32(math.Cos(float64(angle2)))
		y2 := centerY + radius*float32(math.Sin(float64(angle2)))

		rl.DrawLine(int32(x1), int32(y1), int32(x2), int32(y2), color)
	}
}

func drawStar(centerX, centerY, radius float32, color rl.Color) {
	// Draw a 5-pointed star
	numPoints := 5
	for i := 0; i < numPoints; i++ {
		// Outer point
		angle1 := float32(i) * 2 * math.Pi / float32(numPoints)
		x1 := centerX + radius*float32(math.Cos(float64(angle1)))
		y1 := centerY + radius*float32(math.Sin(float64(angle1)))

		// Inner point
		angle2 := angle1 + math.Pi/float32(numPoints)
		x2 := centerX + radius/2*float32(math.Cos(float64(angle2)))
		y2 := centerY + radius/2*float32(math.Sin(float64(angle2)))

		// Next outer point
		angle3 := float32(i+1) * 2 * math.Pi / float32(numPoints)
		x3 := centerX + radius*float32(math.Cos(float64(angle3)))
		y3 := centerY + radius*float32(math.Sin(float64(angle3)))

		rl.DrawLine(int32(x1), int32(y1), int32(x2), int32(y2), color)
		rl.DrawLine(int32(x2), int32(y2), int32(x3), int32(y3), color)
	}
}

func main() {
	// ---------------------------------------------------------
	// 1. Initialize Steamworks
	// ---------------------------------------------------------
	runtime.LockOSThread()

	if err := steamworks.Init(); err != nil {
		panic(fmt.Sprintf("Steamworks failed to initialize: %v\nMake sure Steam is running and steam_appid.txt is present.", err))
	}

	fmt.Println("Steamworks initialized successfully!")

	// ---------------------------------------------------------
	// 2. Initialize Raylib
	// ---------------------------------------------------------
	rl.InitWindow(1280, 720, "Bestagon")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// ---------------------------------------------------------
	// 3. Initialize Game Entities
	// ---------------------------------------------------------
	player := Player{
		Position: Vector2{X: 640, Y: 360},
		Velocity: Vector2{X: 0, Y: 0},
		Speed:    5.0,
		Radius:   20,
	}

	star := Star{
		Position: Vector2{X: 680, Y: 360}, // 40 pixels to the right of player
		Radius:   8,
		Speed:    0.2, // Lerp factor (0-1), lower = springier with more delay
	}

	// ---------------------------------------------------------
	// 4. Game Loop
	// ---------------------------------------------------------
	for !rl.WindowShouldClose() {
		steamworks.RunCallbacks()

		// Update
		player.Update()
		star.Update(player.Position)

		// Draw
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{R: 20, G: 20, B: 30, A: 255})

		// Draw player (hexagon)
		drawHexagon(player.Position.X, player.Position.Y, player.Radius, rl.Green)

		// Draw star
		drawStar(star.Position.X, star.Position.Y, star.Radius, rl.Yellow)

		// Draw UI
		rl.DrawText("BESTAGON", 10, 10, 30, rl.Green)
		rl.DrawText("WASD or Arrows to move", 10, 50, 20, rl.White)

		rl.EndDrawing()
	}
}

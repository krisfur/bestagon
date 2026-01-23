package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
	"path/filepath"

	rl "github.com/gen2brain/raylib-go/raylib"
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

type StarR struct {
	Position Vector2
	Radius   float32
	Speed    float32
}

type StarL struct {
	Position Vector2
	Radius   float32
	Speed    float32
}

type StarB struct {
	Position Vector2
	Radius   float32
	Speed    float32
}

type Enemy struct {
	Position  Vector2
	Size      float32
	Health    float32
	MaxHealth float32
	Color     int // 0 = Red (StarR), 1 = SkyBlue (StarL), 2 = Green (StarB)
}

type GameState struct {
	Player          Player
	StarR           StarR
	StarL           StarL
	StarB           StarB
	Enemies         []Enemy
	StarPower       float32
	MaxStarPower    float32
	EnemySpawnRate  float32
	SpawnTimer      float32
	BaseEnemyHealth float32
	GameOver        bool
	Score           int
	SessionCurrency int64   // Currency earned this run
	TotalCurrency   int64   // Total persistent currency (£)
	ElapsedTime     float32 // Time elapsed since start
}

type SaveData struct {
	TotalCurrency int64 `json:"total_currency"`
}

func getSaveFilePath() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "bestagon_save.json"
	}
	return filepath.Join(homeDir, ".bestagon_save.json")
}

func loadCurrency() int64 {
	saveFile := getSaveFilePath()
	data, err := os.ReadFile(saveFile)
	if err != nil {
		return 0 // No save file, start with 0
	}

	var saveData SaveData
	err = json.Unmarshal(data, &saveData)
	if err != nil {
		return 0
	}

	return saveData.TotalCurrency
}

func saveCurrency(amount int64) error {
	saveData := SaveData{TotalCurrency: amount}
	jsonData, err := json.MarshalIndent(saveData, "", "  ")
	if err != nil {
		return err
	}

	saveFile := getSaveFilePath()
	return os.WriteFile(saveFile, jsonData, 0644)
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

func (s *StarR) Update(playerPos Vector2) {
	targetX := playerPos.X + 40
	targetY := playerPos.Y - 20

	s.Position.X += (targetX - s.Position.X) * s.Speed
	s.Position.Y += (targetY - s.Position.Y) * s.Speed
}

func (s *StarL) Update(playerPos Vector2) {
	targetX := playerPos.X - 40
	targetY := playerPos.Y - 20

	s.Position.X += (targetX - s.Position.X) * s.Speed
	s.Position.Y += (targetY - s.Position.Y) * s.Speed
}

func (s *StarB) Update(playerPos Vector2) {
	targetX := playerPos.X
	targetY := playerPos.Y + float32(math.Sqrt(math.Pow(20, 2)+math.Pow(40, 2)))

	s.Position.X += (targetX - s.Position.X) * s.Speed
	s.Position.Y += (targetY - s.Position.Y) * s.Speed
}

func drawHexagon(centerX, centerY, radius float32, color rl.Color) {
	numSides := 6
	for i := range numSides {
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
	numPoints := 5
	for i := range numPoints {
		angle1 := float32(i) * 2 * math.Pi / float32(numPoints)
		x1 := centerX + radius*float32(math.Cos(float64(angle1)))
		y1 := centerY + radius*float32(math.Sin(float64(angle1)))

		angle2 := angle1 + math.Pi/float32(numPoints)
		x2 := centerX + radius/2*float32(math.Cos(float64(angle2)))
		y2 := centerY + radius/2*float32(math.Sin(float64(angle2)))

		angle3 := float32(i+1) * 2 * math.Pi / float32(numPoints)
		x3 := centerX + radius*float32(math.Cos(float64(angle3)))
		y3 := centerY + radius*float32(math.Sin(float64(angle3)))

		rl.DrawLine(int32(x1), int32(y1), int32(x2), int32(y2), color)
		rl.DrawLine(int32(x2), int32(y2), int32(x3), int32(y3), color)
	}
}

func drawSquare(centerX, centerY, size float32, color rl.Color) {
	halfSize := size / 2
	rl.DrawRectangle(int32(centerX-halfSize), int32(centerY-halfSize), int32(size), int32(size), color)
}

func drawHealthBar(x, y, width, height float32, currentHealth, maxHealth float32, barColor rl.Color) {
	rl.DrawRectangleLines(int32(x), int32(y), int32(width), int32(height), rl.Black)

	healthPercentage := currentHealth / maxHealth
	if healthPercentage < 0 {
		healthPercentage = 0
	}
	rl.DrawRectangle(int32(x), int32(y), int32(width*healthPercentage), int32(height), barColor)
}

func distance(p1, p2 Vector2) float32 {
	dx := p1.X - p2.X
	dy := p1.Y - p2.Y
	return float32(math.Sqrt(float64(dx*dx + dy*dy)))
}

func (gs *GameState) SpawnEnemy() {
	screenWidth := float32(rl.GetScreenWidth())
	screenHeight := float32(rl.GetScreenHeight())

	var newEnemy Enemy
	newEnemy.Size = 30
	newEnemy.MaxHealth = gs.BaseEnemyHealth
	newEnemy.Health = newEnemy.MaxHealth
	newEnemy.Color = rand.Intn(3) // Random color: 0=Yellow, 1=SkyBlue, 2=Green

	edge := rand.Intn(4)
	switch edge {
	case 0: // Top
		newEnemy.Position.X = rand.Float32() * screenWidth
		newEnemy.Position.Y = -15
	case 1: // Bottom
		newEnemy.Position.X = rand.Float32() * screenWidth
		newEnemy.Position.Y = screenHeight + 15
	case 2: // Left
		newEnemy.Position.X = -15
		newEnemy.Position.Y = rand.Float32() * screenHeight
	case 3: // Right
		newEnemy.Position.X = screenWidth + 15
		newEnemy.Position.Y = rand.Float32() * screenHeight
	}

	gs.Enemies = append(gs.Enemies, newEnemy)
}

func (gs *GameState) UpdateEnemies() {
	for i := range gs.Enemies {
		dx := gs.Player.Position.X - gs.Enemies[i].Position.X
		dy := gs.Player.Position.Y - gs.Enemies[i].Position.Y
		dist := distance(gs.Enemies[i].Position, gs.Player.Position)

		if dist > 0 {
			speed := float32(2.0)
			gs.Enemies[i].Position.X += (dx / dist) * speed
			gs.Enemies[i].Position.Y += (dy / dist) * speed
		}
	}

	var livingEnemies []Enemy
	for _, enemy := range gs.Enemies {
		screenWidth := float32(rl.GetScreenWidth())
		screenHeight := float32(rl.GetScreenHeight())
		if enemy.Position.X > -50 && enemy.Position.X < screenWidth+50 &&
			enemy.Position.Y > -50 && enemy.Position.Y < screenHeight+50 {
			livingEnemies = append(livingEnemies, enemy)
		}
	}
	gs.Enemies = livingEnemies
}

func (gs *GameState) CheckCollisions() {
	// Check player-enemy collisions
	for i := range gs.Enemies {
		dist := distance(gs.Player.Position, gs.Enemies[i].Position)
		if dist < gs.Player.Radius+gs.Enemies[i].Size/2 {
			dx := gs.Player.Position.X - gs.Enemies[i].Position.X
			dy := gs.Player.Position.Y - gs.Enemies[i].Position.Y
			bounceDistance := float32(50)
			bounceLength := float32(math.Sqrt(float64(dx*dx + dy*dy)))
			if bounceLength > 0 {
				gs.Player.Position.X += (dx / bounceLength) * bounceDistance
				gs.Player.Position.Y += (dy / bounceLength) * bounceDistance
			}

			gs.StarPower -= 5.0 * 0.5 * 60
			if gs.StarPower < 0 {
				gs.StarPower = 0
			}
		}
	}

	// Check star-enemy collisions with color matching
	starPositions := []Vector2{gs.StarR.Position, gs.StarL.Position, gs.StarB.Position}
	starColors := []int{0, 1, 2} // 0=Yellow, 1=SkyBlue, 2=Green
	starRadius := float32(8)

	for starIdx, starPos := range starPositions {
		starColor := starColors[starIdx]
		for enemyIdx := range gs.Enemies {
			// Only allow damage if star color matches enemy color
			if gs.Enemies[enemyIdx].Color != starColor {
				continue
			}

			dist := distance(starPos, gs.Enemies[enemyIdx].Position)
			if dist < starRadius+gs.Enemies[enemyIdx].Size/2 {
				gs.Enemies[enemyIdx].Health -= 25
				if gs.Enemies[enemyIdx].Health <= 0 {
					// Enemy defeated - award currency
					currencyReward := int64(10 + int(gs.BaseEnemyHealth)/2)
					gs.SessionCurrency += currencyReward
					gs.TotalCurrency += currencyReward

					gs.Enemies = append(gs.Enemies[:enemyIdx], gs.Enemies[enemyIdx+1:]...)
					gs.StarPower += 50
					if gs.StarPower > gs.MaxStarPower {
						gs.StarPower = gs.MaxStarPower
					}
					gs.Score += 100

					// Save currency after earning it
					saveCurrency(gs.TotalCurrency)
				}
				break
			}
		}
	}
}

func (gs *GameState) Update() {
	if gs.GameOver {
		if rl.IsKeyPressed(rl.KeySpace) {
			persistentCurrency := gs.TotalCurrency
			*gs = createGameState(persistentCurrency)
		}
		return
	}

	gs.Player.Update()
	gs.StarR.Update(gs.Player.Position)
	gs.StarL.Update(gs.Player.Position)
	gs.StarB.Update(gs.Player.Position)

	gs.UpdateEnemies()
	gs.CheckCollisions()

	gs.SpawnTimer -= 1.0 / 60.0
	if gs.SpawnTimer <= 0 {
		gs.SpawnEnemy()
		gs.SpawnTimer = gs.EnemySpawnRate
	}

	gs.StarPower -= 0.5
	if gs.StarPower < 0 {
		gs.StarPower = 0
		gs.GameOver = true
	}

	gs.ElapsedTime += 1.0 / 60.0

	// Increase difficulty faster over time (enemies get tougher)
	// Starts at 20 health, increases by 4 per second
	gs.BaseEnemyHealth = 20.0 + (gs.ElapsedTime * 4)

	gs.EnemySpawnRate = 2.0 - (float32(gs.Score) / 5000.0)
	if gs.EnemySpawnRate < 0.5 {
		gs.EnemySpawnRate = 0.5
	}
}

func (gs *GameState) Draw() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{R: 20, G: 20, B: 30, A: 255})

	if !gs.GameOver {
		drawHexagon(gs.Player.Position.X, gs.Player.Position.Y, gs.Player.Radius, rl.Magenta)

		drawStar(gs.StarR.Position.X, gs.StarR.Position.Y, gs.StarR.Radius, rl.Red)
		drawStar(gs.StarL.Position.X, gs.StarL.Position.Y, gs.StarL.Radius, rl.SkyBlue)
		drawStar(gs.StarB.Position.X, gs.StarB.Position.Y, gs.StarB.Radius, rl.Green)

		for _, enemy := range gs.Enemies {
			// Draw enemy with color matching the star that can damage it
			var enemyColor rl.Color
			switch enemy.Color {
			case 0: // Red (matching StarR)
				enemyColor = rl.Red
			case 1: // SkyBlue (matching StarL)
				enemyColor = rl.SkyBlue
			case 2: // Green (matching StarB)
				enemyColor = rl.Green
			default:
				enemyColor = rl.Red
			}

			drawSquare(enemy.Position.X, enemy.Position.Y, enemy.Size, enemyColor)

			barWidth := float32(enemy.Size)
			drawHealthBar(enemy.Position.X-barWidth/2, enemy.Position.Y-enemy.Size/2-15, barWidth, 5, enemy.Health, enemy.MaxHealth, rl.Lime)
		}

		barWidth := float32(400)
		barHeight := float32(30)
		barX := float32(rl.GetScreenWidth())/2 - barWidth/2
		barY := float32(50)

		drawHealthBar(barX, barY, barWidth, barHeight, gs.StarPower, gs.MaxStarPower, rl.Gold)
		rl.DrawText("STAR POWER", int32(barX+10), int32(barY+6), 16, rl.White)

		rl.DrawText("BESTAGON", 10, 10, 30, rl.Green)
		rl.DrawText("WASD or Arrows to move", 10, 90, 20, rl.White)

		// Draw persistent currency at top right
		currencyStr := fmt.Sprintf("£%d", gs.TotalCurrency)
		rl.DrawText(currencyStr, int32(rl.GetScreenWidth())-150, 10, 20, rl.Gold)

		// Draw session currency earned this run
		sessionStr := fmt.Sprintf("Session: £%d", gs.SessionCurrency)
		rl.DrawText(sessionStr, int32(rl.GetScreenWidth())-150, 40, 16, rl.Red)

	} else {
		rl.DrawText("GAME OVER", int32(rl.GetScreenWidth()/2-150), int32(rl.GetScreenHeight()/2-80), 60, rl.Red)

		scoreStr := fmt.Sprintf("Score: %d", gs.Score)
		rl.DrawText(scoreStr, int32(rl.GetScreenWidth()/2-80), int32(rl.GetScreenHeight()/2-10), 30, rl.White)

		currencyStr := fmt.Sprintf("Earned: £%d", gs.SessionCurrency)
		rl.DrawText(currencyStr, int32(rl.GetScreenWidth()/2-100), int32(rl.GetScreenHeight()/2+40), 30, rl.Gold)

		totalStr := fmt.Sprintf("Total: £%d", gs.TotalCurrency)
		rl.DrawText(totalStr, int32(rl.GetScreenWidth()/2-90), int32(rl.GetScreenHeight()/2+80), 30, rl.Gold)

		rl.DrawText("Press SPACE to restart", int32(rl.GetScreenWidth()/2-150), int32(rl.GetScreenHeight()/2+140), 25, rl.Red)
	}

	rl.EndDrawing()
}

func createGameState(persistentCurrency int64) GameState {
	return GameState{
		Player: Player{
			Position: Vector2{X: 640, Y: 360},
			Velocity: Vector2{X: 0, Y: 0},
			Speed:    5.0,
			Radius:   20,
		},
		StarR: StarR{
			Position: Vector2{X: 680, Y: 340},
			Radius:   8,
			Speed:    0.2,
		},
		StarL: StarL{
			Position: Vector2{X: 600, Y: 340},
			Radius:   8,
			Speed:    0.2,
		},
		StarB: StarB{
			Position: Vector2{X: 640, Y: 400},
			Radius:   8,
			Speed:    0.2,
		},
		Enemies:         []Enemy{},
		StarPower:       1800,
		MaxStarPower:    1800,
		EnemySpawnRate:  2.0,
		SpawnTimer:      2.0,
		BaseEnemyHealth: 20.0,
		GameOver:        false,
		Score:           0,
		SessionCurrency: 0,
		TotalCurrency:   persistentCurrency,
		ElapsedTime:     0,
	}
}

func main() {
	rl.InitWindow(1280, 720, "Bestagon")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	persistentCurrency := loadCurrency()
	gameState := createGameState(persistentCurrency)

	for !rl.WindowShouldClose() {
		gameState.Update()
		gameState.Draw()
	}
}

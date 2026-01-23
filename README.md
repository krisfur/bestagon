# Bestagon

Go game to be with raylib.

## How to add the steam SDK later

in imports add:

```go
import (
	//[...]
	steamworks "github.com/hajimehoshi/go-steamworks"
)
```

at the start of main add:

```go
	// ---------------------------------------------------------
	// 1. Initialize Steamworks
	// ---------------------------------------------------------
	runtime.LockOSThread()

	if err := steamworks.Init(); err != nil {
		panic(fmt.Sprintf("Steamworks failed to initialize: %v\nMake sure Steam is running and steam_appid.txt is present.", err))
	}

	fmt.Println("Steamworks initialized successfully!")
```

inside the game loop add:

```go
	// ---------------------------------------------------------
	// 4. Game Loop
	// ---------------------------------------------------------
	for !rl.WindowShouldClose() {
		steamworks.RunCallbacks()
````

1. Download the steam SDK [here](https://partner.steamgames.com/doc/sdk)
2. Copy libsteam_api.so (Linux) or steam_api64.dll (Windows) to the root folder.
3. Create a steam_appid.txt file containing 480.

Then with steam running in the background simply run:

```bash
go run .
```

package main


import (
	"embed"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)


//go:embed all:frontend/dist
var assets embed.FS


func main() {
	app := NewApp()

	RegisterRouter()

	err := wails.Run(&options.App{
		Title:  "Go Transfer",
		Width:  800,
		Height: 550,
		MinWidth: 800,
		MinHeight: 550,
		MaxWidth: 950,
		MaxHeight: 650,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 27, G: 38, B: 54, A: 1},
		OnStartup:        app.startup,
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
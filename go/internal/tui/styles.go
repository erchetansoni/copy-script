package tui

import "github.com/charmbracelet/lipgloss"

// Palette defines the high-contrast industrial theme colors.
var (
	ColorPrimary   = lipgloss.Color("#58a6ff") // Bright Blue
	ColorSecondary = lipgloss.Color("#a78bfa") // Purple / Security
	ColorSuccess   = lipgloss.Color("#34d399") // Emerald Green
	ColorWarning   = lipgloss.Color("#f59e0b") // Amber Warning
	ColorDanger    = lipgloss.Color("#f87171") // Coral Red
	ColorMuted     = lipgloss.Color("#6b7280") // Slate Muted
	ColorBgDark    = lipgloss.Color("#121319") // Dark Background
	ColorCardBg    = lipgloss.Color("#1a1b26") // Card Surface
	ColorBorder    = lipgloss.Color("#2e3245") // Subtle Border
	ColorHighlight = lipgloss.Color("#e0af68") // Accent Gold
)

// Lip Gloss Styles
var (
	StyleApp = lipgloss.NewStyle().
			Padding(0, 1)

	StyleHeader = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#ffffff")).
			Background(lipgloss.Color("#1f2335")).
			Padding(0, 1)

	StyleSubHeader = lipgloss.NewStyle().
			Foreground(ColorMuted).
			PaddingLeft(1)

	StylePillSuccess = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#000000")).
				Background(ColorSuccess).
				Bold(true).
				Padding(0, 1)

	StylePillPrimary = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#ffffff")).
				Background(ColorPrimary).
				Bold(true).
				Padding(0, 1)

	StylePillWarning = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#000000")).
				Background(ColorWarning).
				Bold(true).
				Padding(0, 1)

	StylePillSecondary = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#ffffff")).
				Background(ColorSecondary).
				Bold(true).
				Padding(0, 1)

	StylePillMuted = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#ffffff")).
			Background(ColorMuted).
			Padding(0, 1)

	StyleTabActive = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#ffffff")).
			Background(ColorPrimary).
			Padding(0, 2)

	StyleTabInactive = lipgloss.NewStyle().
				Foreground(ColorMuted).
				Background(lipgloss.Color("#24283b")).
				Padding(0, 2)

	StyleCard = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorBorder).
			Background(ColorCardBg).
			Padding(0, 1)

	StyleCardTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorPrimary).
			PaddingBottom(0)

	StyleKey = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#ffffff")).
			Background(lipgloss.Color("#3b4261")).
			Padding(0, 1)

	StyleKeyDesc = lipgloss.NewStyle().
			Foreground(ColorMuted).
			PaddingRight(1)

	StyleToastSuccess = lipgloss.NewStyle().
				Foreground(ColorSuccess).
				Bold(true).
				Padding(0, 1)

	StyleToastError = lipgloss.NewStyle().
			Foreground(ColorDanger).
			Bold(true).
			Padding(0, 1)

	StyleLogInfo = lipgloss.NewStyle().
			Foreground(ColorPrimary)

	StyleLogSuccess = lipgloss.NewStyle().
			Foreground(ColorSuccess)

	StyleLogWarn = lipgloss.NewStyle().
			Foreground(ColorWarning)

	StyleLogError = lipgloss.NewStyle().
			Foreground(ColorDanger)
)


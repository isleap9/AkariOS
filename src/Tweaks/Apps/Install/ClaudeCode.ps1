# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "claude-code".
@{
    Id          = 'install-claude-code'
    Name        = 'Claude Code'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Anthropic''s coding agent for the terminal.'
    Winget      = 'Anthropic.ClaudeCode'
}

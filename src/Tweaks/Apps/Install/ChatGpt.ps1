# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "chatgpt".
@{
    Id          = 'install-chatgpt'
    Name        = 'ChatGPT'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'OpenAI''s desktop app (from the Microsoft Store).'
    Winget      = '9NT1R1C2HH7J'
    WingetSource = 'msstore'
}

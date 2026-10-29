# USB setup file (UI\Unattend.ps1): the display languages Windows ships, each with its default keyboard (Microsoft's
# default input profiles, as language:layout), and the keyboards the page lists (the defaults plus common layouts).
@{
    Languages = @(
        @{ Tag = 'ar-SA'; Name = 'Arabic (Saudi Arabia)'; Keyboard = '0401:00000401' }
        @{ Tag = 'bg-BG'; Name = 'Bulgarian'; Keyboard = '0402:00030402' }
        @{ Tag = 'cs-CZ'; Name = 'Czech'; Keyboard = '0405:00000405' }
        @{ Tag = 'da-DK'; Name = 'Danish'; Keyboard = '0406:00000406' }
        @{ Tag = 'de-DE'; Name = 'German (Germany)'; Keyboard = '0407:00000407' }
        @{ Tag = 'el-GR'; Name = 'Greek'; Keyboard = '0408:00000408' }
        @{ Tag = 'en-GB'; Name = 'English (United Kingdom)'; Keyboard = '0809:00000809' }
        @{ Tag = 'en-US'; Name = 'English (United States)'; Keyboard = '0409:00000409' }
        @{ Tag = 'es-ES'; Name = 'Spanish (Spain)'; Keyboard = '0C0A:0000040A' }
        @{ Tag = 'es-MX'; Name = 'Spanish (Mexico)'; Keyboard = '080A:0000080A' }
        @{ Tag = 'et-EE'; Name = 'Estonian'; Keyboard = '0425:00000425' }
        @{ Tag = 'fi-FI'; Name = 'Finnish'; Keyboard = '040B:0000040B' }
        @{ Tag = 'fr-CA'; Name = 'French (Canada)'; Keyboard = '0C0C:00001009' }
        @{ Tag = 'fr-FR'; Name = 'French (France)'; Keyboard = '040C:0000040C' }
        @{ Tag = 'he-IL'; Name = 'Hebrew'; Keyboard = '040D:0000040D' }
        @{ Tag = 'hr-HR'; Name = 'Croatian'; Keyboard = '041A:0000041A' }
        @{ Tag = 'hu-HU'; Name = 'Hungarian'; Keyboard = '040E:0000040E' }
        @{ Tag = 'it-IT'; Name = 'Italian'; Keyboard = '0410:00000410' }
        @{ Tag = 'ja-JP'; Name = 'Japanese'; Keyboard = '0411:00000411' }
        @{ Tag = 'ko-KR'; Name = 'Korean'; Keyboard = '0412:00000412' }
        @{ Tag = 'lt-LT'; Name = 'Lithuanian'; Keyboard = '0427:00010427' }
        @{ Tag = 'lv-LV'; Name = 'Latvian'; Keyboard = '0426:00000426' }
        @{ Tag = 'nb-NO'; Name = 'Norwegian (Bokmal)'; Keyboard = '0414:00000414' }
        @{ Tag = 'nl-NL'; Name = 'Dutch (Netherlands)'; Keyboard = '0413:00020409' }
        @{ Tag = 'pl-PL'; Name = 'Polish'; Keyboard = '0415:00000415' }
        @{ Tag = 'pt-BR'; Name = 'Portuguese (Brazil)'; Keyboard = '0416:00000416' }
        @{ Tag = 'pt-PT'; Name = 'Portuguese (Portugal)'; Keyboard = '0816:00000816' }
        @{ Tag = 'ro-RO'; Name = 'Romanian'; Keyboard = '0418:00010418' }
        @{ Tag = 'ru-RU'; Name = 'Russian'; Keyboard = '0419:00000419' }
        @{ Tag = 'sk-SK'; Name = 'Slovak'; Keyboard = '041B:0000041B' }
        @{ Tag = 'sl-SI'; Name = 'Slovenian'; Keyboard = '0424:00000424' }
        @{ Tag = 'sr-Latn-RS'; Name = 'Serbian (Latin)'; Keyboard = '241A:0000081A' }
        @{ Tag = 'sv-SE'; Name = 'Swedish'; Keyboard = '041D:0000041D' }
        @{ Tag = 'th-TH'; Name = 'Thai'; Keyboard = '041E:0000041E' }
        @{ Tag = 'tr-TR'; Name = 'Turkish'; Keyboard = '041F:0000041F' }
        @{ Tag = 'uk-UA'; Name = 'Ukrainian'; Keyboard = '0422:00000422' }
        @{ Tag = 'zh-CN'; Name = 'Chinese (Simplified)'; Keyboard = '0804:00000804' }
        @{ Tag = 'zh-TW'; Name = 'Chinese (Traditional)'; Keyboard = '0404:00000404' }
    )
    Keyboards = @(
        @{ Id = '0401:00000401'; Name = 'Arabic (101)' }
        @{ Id = '0402:00030402'; Name = 'Bulgarian' }
        @{ Id = '0405:00000405'; Name = 'Czech' }
        @{ Id = '0406:00000406'; Name = 'Danish' }
        @{ Id = '0407:00000407'; Name = 'German' }
        @{ Id = '0807:00000807'; Name = 'Swiss German' }
        @{ Id = '0408:00000408'; Name = 'Greek' }
        @{ Id = '0809:00000809'; Name = 'United Kingdom' }
        @{ Id = '0809:00000452'; Name = 'United Kingdom Extended' }
        @{ Id = '0409:00000409'; Name = 'US' }
        @{ Id = '0409:00020409'; Name = 'United States-International' }
        @{ Id = '0409:00010409'; Name = 'United States-Dvorak' }
        @{ Id = '0409:00000809'; Name = 'English (US) with the United Kingdom layout' }
        @{ Id = '0C0A:0000040A'; Name = 'Spanish' }
        @{ Id = '080A:0000080A'; Name = 'Latin American' }
        @{ Id = '0425:00000425'; Name = 'Estonian' }
        @{ Id = '040B:0000040B'; Name = 'Finnish' }
        @{ Id = '0C0C:00001009'; Name = 'Canadian French' }
        @{ Id = '1009:00011009'; Name = 'Canadian Multilingual Standard' }
        @{ Id = '040C:0000040C'; Name = 'French' }
        @{ Id = '100C:0000100C'; Name = 'Swiss French' }
        @{ Id = '080C:0000080C'; Name = 'Belgian French' }
        @{ Id = '0813:00000813'; Name = 'Belgian (Period)' }
        @{ Id = '040D:0000040D'; Name = 'Hebrew' }
        @{ Id = '041A:0000041A'; Name = 'Croatian' }
        @{ Id = '040E:0000040E'; Name = 'Hungarian' }
        @{ Id = '0410:00000410'; Name = 'Italian' }
        @{ Id = '0411:00000411'; Name = 'Japanese' }
        @{ Id = '0412:00000412'; Name = 'Korean' }
        @{ Id = '0427:00010427'; Name = 'Lithuanian' }
        @{ Id = '0426:00000426'; Name = 'Latvian' }
        @{ Id = '0414:00000414'; Name = 'Norwegian' }
        @{ Id = '0413:00020409'; Name = 'Dutch (United States-International)' }
        @{ Id = '0413:00000413'; Name = 'Dutch' }
        @{ Id = '0415:00000415'; Name = 'Polish (Programmers)' }
        @{ Id = '0416:00000416'; Name = 'Portuguese (Brazil ABNT)' }
        @{ Id = '0416:00010416'; Name = 'Portuguese (Brazil ABNT2)' }
        @{ Id = '0816:00000816'; Name = 'Portuguese' }
        @{ Id = '0418:00010418'; Name = 'Romanian (Standard)' }
        @{ Id = '0419:00000419'; Name = 'Russian' }
        @{ Id = '041B:0000041B'; Name = 'Slovak' }
        @{ Id = '0424:00000424'; Name = 'Slovenian' }
        @{ Id = '241A:0000081A'; Name = 'Serbian (Latin)' }
        @{ Id = '041D:0000041D'; Name = 'Swedish' }
        @{ Id = '041E:0000041E'; Name = 'Thai Kedmanee' }
        @{ Id = '041F:0000041F'; Name = 'Turkish Q' }
        @{ Id = '0422:00000422'; Name = 'Ukrainian' }
        @{ Id = '0804:00000804'; Name = 'Chinese (Simplified) - US' }
        @{ Id = '0404:00000404'; Name = 'Chinese (Traditional) - US' }
    )
}

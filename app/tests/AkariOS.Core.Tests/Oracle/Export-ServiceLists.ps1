# The reference for the native Services and Scheduled tasks lists (app/AkariOS.Core/Tweaks/ServiceLists.cs,
# TaskLists.cs): the pure functions of src\UI\ServicesPage.ps1 and TasksPage.ps1 (read out of the files: their WPF
# parts never load) and Core\System.ps1's start type helpers, on made-up services and tasks (-Services / -Tasks: JSON
# files the C# test wrote) and the real services.psd1 / tasks.psd1, written as JSON for ServiceListsOracleTests.
# $Queries: the searches, comma separated.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Services,
    [Parameter(Mandatory)][string]$Tasks, [string]$Queries = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\System.ps1')
foreach ($f in 'ServicesPage.ps1', 'TasksPage.ps1') {
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src "UI\$f"), [ref]$null, [ref]$null)
    foreach ($n in $ast.EndBlock.Statements) {
        if ($n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -notmatch 'Bar|Show-|Start-|Complete-|New-|Set-Akari|Invoke-') { . ([scriptblock]::Create($n.Extent.Text)) }
        elseif ($n -is [Management.Automation.Language.AssignmentStatementAst] -and "$($n.Left)" -match '^\$Akari') { . ([scriptblock]::Create($n.Extent.Text)) }
    }
}
$searches = @('') + @($Queries.Split(',') | Where-Object { $_ })
# 5.1's ConvertFrom-Json outputs an array as one object: unrolled
$svcs = @((Get-Content -LiteralPath $Services -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
$tks = @((Get-Content -LiteralPath $Tasks -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
$defaults = Get-AkariServiceDefaults (Join-Path $Src $AkariServiceDefaultsPath)
$suggest = Get-AkariServiceSuggestions (Join-Path $Src $AkariServiceDefaultsPath)
$taskSuggest = Get-AkariTaskSuggestions (Join-Path $Src $AkariTaskSuggestPath)

$svcViews = [ordered]@{}
foreach ($f in $AkariServiceFilters) {
    foreach ($q in $searches) {
        $svcViews["$f|$q|all"] = @(Get-AkariServiceView $svcs $f $q $defaults $null | ForEach-Object { $_.Name })
        $svcViews["$f|$q|suggested"] = @(Get-AkariServiceView $svcs $f $q $defaults $suggest | ForEach-Object { $_.Name })
    }
}
$taskViews = [ordered]@{}
foreach ($f in $AkariTaskFilters) {
    foreach ($q in $searches) {
        $taskViews["$f|$q|all"] = @(Get-AkariTaskView $tks $f $q $null | ForEach-Object { Get-AkariTaskKey $_ })
        $taskViews["$f|$q|suggested"] = @(Get-AkariTaskView $tks $f $q $taskSuggest | ForEach-Object { Get-AkariTaskKey $_ })
    }
}
$perService = [ordered]@{}
foreach ($s in $svcs) {
    $perService[[string]$s.Name] = [ordered]@{
        Template = Get-AkariServiceTemplate $s.Name
        Default = Get-AkariServiceDefault $s $defaults
        Suggestion = @(Get-AkariServiceSuggestion $s $suggest)
        Changed = [bool](Test-AkariServiceChanged $s $defaults)
        Action = Get-AkariServiceAction $s
        Disable = Get-AkariServiceConfirm $s 'StartType' 'Disabled'
        Manual = Get-AkariServiceConfirm $s 'StartType' 'Manual'
        Stop = Get-AkariServiceConfirm $s 'Control' 'Stop'
        Start = Get-AkariServiceConfirm $s 'Control' 'Start'
    }
}
$perTask = [ordered]@{}
foreach ($t in $tks) {
    $r = Get-AkariTaskSuggestion $t $taskSuggest
    $perTask[[string](Get-AkariTaskKey $t)] =if ($r) { "$($r.Source) ($($r.Note))" } else { '' }
}
$types = [ordered]@{}
foreach ($m in 'Auto', 'Manual', 'Disabled', 'Boot', 'System') { foreach ($d in $false, $true) { $types["$m|$d"] = ConvertTo-AkariStartType $m $d } }
$values = [ordered]@{}
foreach ($k in $AkariStartTypes.Keys) { $v = ConvertFrom-AkariStartType $k; $values[[string]$k] ="$($v.Start)|$($v.Delayed)" }
$result = [ordered]@{
    StartTypes = @($AkariStartTypes.Keys | ForEach-Object { "$_=$($AkariStartTypes[$_])" })
    Filters = $AkariServiceFilters; TaskFilters = $AkariTaskFilters; Critical = $AkariCriticalServices
    Defaults = $defaults; Suggestions = $suggest
    ServiceViews = $svcViews; TaskViews = $taskViews; PerService = $perService; PerTask = $perTask
    Types = $types; Values = $values
    Labels = @(2, 3, 4, 1 | ForEach-Object { Get-AkariStartLabel $_ })
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))

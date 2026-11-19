# What UI\Shell.ps1 gives the page files, for the in-memory probes that load UI\Steps.ps1, UI\Apps.ps1 and UI\Pages.ps1
# without a window: the page's parts and the shell functions they call (the header, the footer, history, Show-Page,
# toasts). Dot-sourced after the UI files; a probe redefines what it wants to record.

$StepBody = [Windows.Controls.StackPanel]::new()
$StepsPanel = [Windows.Controls.StackPanel]::new(); $HomePanel = [Windows.Controls.StackPanel]::new(); $Rows = [Windows.Controls.StackPanel]::new()
$CatBars = [Windows.Controls.StackPanel]::new()
$StepFooter = [Windows.Controls.Border]::new(); $StepFooter.Visibility = 'Collapsed'
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new()
$StepLabel = [Windows.Controls.TextBlock]::new(); $StepFill = [Windows.Shapes.Rectangle]::new()
$Heading = [Windows.Controls.TextBlock]::new(); $Crumbs = [Windows.Controls.StackPanel]::new(); $PageHeader = [Windows.Controls.WrapPanel]::new()
$Search = [Windows.Controls.TextBox]::new()
$Layer = [Windows.Controls.Border]::new()
$script:History = [Collections.Generic.List[object]]::new()
$script:Toasts = @(); $script:Activity = @()

# the breadcrumb: the earlier parts' labels in $Crumbs, the last one in $Heading
function Set-AkariHeader($Parts) {
    $Crumbs.Children.Clear()
    $p = @($Parts)
    if (-not $p.Count) { $Heading.Text = ''; return }
    for ($i = 0; $i -lt $p.Count - 1; $i++) { [void]$Crumbs.Children.Add([Windows.Controls.TextBlock]@{ Text = $(if ($p[$i] -is [array]) { $p[$i][0] } else { $p[$i] }) }) }
    $Heading.Text = if ($p[-1] -is [array]) { $p[-1][0] } else { $p[-1] }
}
function Push-AkariHistory { $script:History.Add(@{ Cat = $script:Cat; Mode = $script:Mode; Step = $script:Step }) }
function Set-AkariFooter([bool]$On) { $StepFooter.Visibility = if ($On) { 'Visible' } else { 'Collapsed' } }
function Show-Page {
    $StepBody.Children.Clear()
    Set-AkariFooter $false
    switch ($script:Cat) {
        'Install AkariOS' { Show-AkariSteps }
        'Downloads' { Show-AkariDownloads }
        'Remove apps' { Show-AkariRemoveApps }
        default { $script:shownPage = $script:Cat }
    }
}
function Select-AkariPage($n) { $script:went = $n; $script:Cat = $n }
function Update-AkariCatalogueBars { }
function Show-AkariToast { $script:Toasts += , @($args) }
function Add-AkariActivity { $script:Activity += , @($args) }

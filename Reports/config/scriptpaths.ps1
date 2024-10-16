$ScriptPath = (Get-Location).Path
$ScriptParent = $ScriptPath | Split-Path -Parent
$ScriptGParent = $ScriptParent | Split-Path -Parent
$Script2GParent = $ScriptGParent | Split-Path -Parent
if (Get-Command jj -ErrorAction SilentlyContinue) {
  try {
    $env:COMPLETE = "powershell"
    jj | Out-String | Invoke-Expression
  } finally {
    Remove-Item Env:\COMPLETE -ErrorAction SilentlyContinue
  }
}

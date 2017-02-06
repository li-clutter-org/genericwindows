<#
Copyright 2016 Load Impact
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
    
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<# Run Load Impact test from Powershell #>

<# Load Impact test id #>
$testId = YOUR_TEST_ID_HERE
<# API_KEY from your Load Impact account #>
$API_KEY = "YOUR_API_KEY_HERE" + ":"

$auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($API_KEY))

$uri = "https://api.loadimpact.com/v2/test-configs/" + $testId + "/start"

Write-Host "Load Impact performance test"
Write-Host "Kickoff performance test"

<# try-catch because PS considers all 400+ codes to be errors and will exit if returned #>
$resp = $null
try {
  $resp = Invoke-WebRequest -uri $uri -Method Post -Headers @{'Authorization'=$auth}
} catch {}

<# Status 201 expected, 200 is just a current running test id #>

if ($resp.StatusCode -ne 201) {
  Write-Host  "Could not start test " + $testId + ": " + $resp.StatusCode + "`n" + $resp.Content
  return
}

$js = ConvertFrom-Json -InputObject $resp.Content

$tid = $js.id

<# Until 5 minutes timout or status is running   #> 

$t = 0
$uri = "https://api.loadimpact.com/v2/tests/" + $tid + "/"
do {
  Start-Sleep -Seconds 10
  $resp = Invoke-WebRequest -uri $uri -Method Get -Headers @{'Authorization'=$auth}
  $j = ConvertFrom-Json -InputObject $resp.Content
  $status_text = $j.status_text
  $t = $t + 10

  if ($t -gt 300) {
    Write-Host "Timeout - test start > 5 min" 
    return
  }
} until ($status_text -eq "Running")

Write-Host "Performance test running"

<# wait until completed #>

$maxVULoadTime = 0.0
$percentage = 0.0
$uri = "https://api.loadimpact.com/v2/tests/" + $tid + "/results?ids=__li_progress_percent_total"
$uril = "https://api.loadimpact.com/v2/tests/" + $tid + "/results?ids=__li_user_load_time"
do {
  Start-Sleep -Seconds 30

  <# Get percent completed #>
  $resp = Invoke-WebRequest -uri $uri -Method Get -Headers @{'Authorization'=$auth}
  $j = ConvertFrom-Json -InputObject $resp.Content

  <# Since -Last 1 will get TWO on occassion we sort and get the first which will always get 1 #>
  $percentage = ($j.__li_progress_percent_total | Sort value -Descending | Select-Object -First 1).value

  Write-Host "Percentage completed $percentage"

  <# Get VU Load Time #>
  $resp = Invoke-WebRequest -uri $uril -Method Get -Headers @{'Authorization'=$auth}
  $j = ConvertFrom-Json -InputObject $resp.Content

  <# Sort and get the highest value #>
  $maxVULoadTime = ($j.__li_user_load_time | Sort value -Descending | Select-Object -First 1).value

  if ($maxVULoadTime -gt 1000) {
    Write-Host "VU Load Time exceeded limit of 1 sec: $maxVULoadTime"
    return
  }


} until ([double]$percentage -eq 100.0)

<# show results #>
Write-Host "Show results"
Write-Host "Max VU Load Time: $maxVULoadTime"
Write-Host "Full results at https://app.loadimpact.com/test-runs/$tid"


param(
  [string]$Base = "http://localhost:8080",
  [string]$Password = "Password123"
)
$script:failures = 0

function Api {
  param($Method, $Path, $Body = $null, $Token = $null)
  $p = @{ Uri = "$Base$Path"; Method = $Method; UseBasicParsing = $true; Headers = @{} }
  if ($Token) { $p.Headers["Authorization"] = "Bearer $Token" }
  if ($null -ne $Body) {
    $p.Body = ($Body | ConvertTo-Json -Depth 8)
    $p.ContentType = "application/json"
  }
  try {
    $r = Invoke-WebRequest @p
    $json = $null
    if ($r.Content) { try { $json = $r.Content | ConvertFrom-Json } catch {} }
    [pscustomobject]@{ Status = [int]$r.StatusCode; Json = $json; Response = $r; Text = "" }
  } catch {
    $status = 0; $text = ""
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
      else { try { $text = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {} }
    }
    $json = $null
    try { $json = $text | ConvertFrom-Json } catch {}
    [pscustomobject]@{ Status = $status; Json = $json; Response = $null; Text = $text }
  }
}

function Check($Name, $Ok, $Detail = "") {
  if ($Ok) { Write-Host "PASS  $Name" -ForegroundColor Green }
  else { Write-Host "FAIL  $Name  $Detail" -ForegroundColor Red; $script:failures++ }
}

# --- health and events (public) ---
$r = Api GET "/api/health"
Check "health" ($r.Status -eq 200) "status $($r.Status)"

$r = Api GET "/api/events"
Check "events list is public" ($r.Status -eq 200) "status $($r.Status)"
$events = @($r.Json | Where-Object { $_ })
Write-Host "      $($events.Count) event(s) on the server"
if ($events.Count -eq 0) {
  Write-Host "WARN  no events: the app should show 'No events available'" -ForegroundColor Yellow
}
$ev = $events | Select-Object -First 1
if ($ev) {
  $names = $ev.PSObject.Properties.Name
  foreach ($f in "id","title","category","venue","startTime","status","availability","coverImagePath","minPrice","ticketTypes") {
    Check "event has field '$f'" ($names -contains $f)
  }
  if ($ev.coverImagePath) {
    $img = Api GET $ev.coverImagePath
    $type = "$($img.Response.Headers['Content-Type'])"
    Check "cover image is served" (($img.Status -eq 200) -and ($type -like "image/*")) "status $($img.Status) type $type"
  } else {
    Write-Host "WARN  first event has no coverImagePath" -ForegroundColor Yellow
  }
}

# --- auth ---
$email = "smoke" + [guid]::NewGuid().ToString("N").Substring(0,8) + "@test.com"
$reg = @{ name = "Smoke Test"; email = $email; password = $Password; role = "CUSTOMER" }
$r = Api POST "/api/auth/register" $reg
Check "register new customer" (($r.Status -eq 200) -or ($r.Status -eq 201)) "status $($r.Status) $($r.Text)"
Check "register returns token and user" ([bool]$r.Json.token -and [bool]$r.Json.user)
$r = Api POST "/api/auth/register" $reg
Check "duplicate email gives 409" ($r.Status -eq 409) "status $($r.Status)"
$r = Api POST "/api/auth/login" @{ email = "customer@test.com"; password = "wrong-password" }
Check "wrong password gives 401" ($r.Status -eq 401) "status $($r.Status)"

$r = Api POST "/api/auth/login" @{ email = "customer@test.com"; password = $Password }
Check "customer login" (($r.Status -eq 200) -and [bool]$r.Json.token) "status $($r.Status)"
$tok = $r.Json.token
if (-not $tok) { Write-Host "Stopping: no token (is the dev seed on?)" -ForegroundColor Red; exit 1 }

$r = Api GET "/api/customers/me" $null $tok
Check "profile works with a token" ($r.Status -eq 200) "status $($r.Status)"
$r = Api GET "/api/customers/me"
Check "profile needs a token" (($r.Status -eq 401) -or ($r.Status -eq 403)) "status $($r.Status)"

# --- order, payment, tickets ---
if (-not $ev) {
  Write-Host "Skipping order tests: no events." -ForegroundColor Yellow
} else {
  $tt = @($ev.ticketTypes) | Select-Object -First 1
  $r = Api POST "/api/orders" @{ eventId = $ev.id; items = @(@{ ticketTypeId = $tt.id; quantity = 1 }) } $tok
  Check "place order" ((($r.Status -eq 200) -or ($r.Status -eq 201)) -and [bool]$r.Json.id) "status $($r.Status) $($r.Text)"
  $orderId = $r.Json.id

  $r = Api POST "/api/orders/$orderId/status" @{ status = "PAID" }
  Check "anonymous order status change is blocked" (@(401,403,404) -contains $r.Status) "status $($r.Status)"

  $r = Api POST "/api/payments/checkout" @{ orderId = $orderId } $tok
  if ($r.Status -eq 200) {
    Check "checkout returns txRef and checkoutUrl" ([bool]$r.Json.txRef -and [bool]$r.Json.checkoutUrl)
  } else {
    Write-Host "WARN  checkout gave $($r.Status): PayChangu test key missing or gateway unreachable? $($r.Text)" -ForegroundColor Yellow
  }

  $r = Api POST "/api/dev/orders/$orderId/mark-paid" $null $tok
  Check "demo mark-paid issues tickets" (($r.Status -eq 200) -and (@($r.Json.tickets).Count -ge 1)) "status $($r.Status) $($r.Text)"

  $r = Api GET "/api/tickets/my" $null $tok
  $t = @($r.Json | Where-Object { $_ }) | Where-Object { "$($_.orderId)" -eq "$orderId" } | Select-Object -First 1
  Check "my tickets contains the new ticket" ([bool]$t)
  if ($t) {
    foreach ($f in "ticketCode","qrContent","buyerName","paymentReference","eventTitle","ticketTypeName") {
      Check "ticket has '$f'" ([bool]$t.$f)
    }
    $v = Api POST "/api/auth/login" @{ email = "validator@test.com"; password = $Password }
    $vt = $v.Json.token
    $r = Api POST "/api/tickets/validate" @{ ticketCode = $t.ticketCode } $tok
    Check "customer cannot validate tickets" ($r.Status -eq 403) "status $($r.Status)"
    $r = Api POST "/api/tickets/validate" @{ ticketCode = $t.ticketCode } $vt
    Check "validator scan marks the ticket USED" (($r.Status -eq 200) -and ($r.Json.status -eq "USED")) "status $($r.Status)"
    $r = Api POST "/api/tickets/validate" @{ ticketCode = $t.ticketCode } $vt
    Check "second scan is rejected (409)" ($r.Status -eq 409) "status $($r.Status)"
  }
}

Write-Host ""
if ($script:failures -eq 0) { Write-Host "All checks passed." -ForegroundColor Green }
else { Write-Host "$($script:failures) check(s) failed." -ForegroundColor Red }
exit $script:failures
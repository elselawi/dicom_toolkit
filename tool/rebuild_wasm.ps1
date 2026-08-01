# Rebuild WASM artifacts for web
# Prerequisites: Rust nightly toolchain, wasm-pack, wasm32-unknown-unknown target
#
# Usage: .\tool\rebuild_wasm.ps1
#   -Release   Build in release mode (smaller, slower to compile)
#
# Output: web/pkg/ and rust/pkg/ (both updated)

param(
    [switch]$Release
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..\rust

$profile = if ($Release) { "--release" } else { "--dev" }

Write-Output "Building WASM ($profile)..."

$env:RUSTUP_TOOLCHAIN = 'nightly'
$env:RUSTFLAGS = '-C target-feature=+atomics,+bulk-memory,+mutable-globals -C link-args=--shared-memory -C link-args=--max-memory=2147483648 -C link-args=--import-memory -C link-args=--export=__heap_base -C link-args=--export=__wasm_init_tls -C link-args=--export=__tls_size -C link-args=--export=__tls_align -C link-args=--export=__tls_base'

# Build to rust/pkg/ first
# Note: explicit '.' path required before '--' cargo args
wasm-pack build -t no-modules -d pkg --no-typescript --out-name dicom_toolkit $profile . -- -Z build-std=std,panic_abort 2>&1 | Select-String -NotMatch "wasm-validator|wasm-opt" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "wasm-pack build failed" }

# wasm-pack creates a .gitignore that blocks everything — remove it
Remove-Item pkg\.gitignore -Force -ErrorAction SilentlyContinue

# Copy to web/pkg/ (what Flutter web build picks up)
$webPkg = "..\web\pkg"
Copy-Item pkg\* $webPkg -Force
Remove-Item $webPkg\.gitignore -Force -ErrorAction SilentlyContinue

# Copy to example/web/pkg/ (example app)
$examplePkg = "..\example\web\pkg"
if (Test-Path $examplePkg) {
    Copy-Item pkg\* $examplePkg -Force
    Remove-Item $examplePkg\.gitignore -Force -ErrorAction SilentlyContinue
}

Pop-Location
Write-Output "Done. WASM artifacts in web/pkg/ and rust/pkg/"

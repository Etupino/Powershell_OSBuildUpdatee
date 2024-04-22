param (
    [switch]$Elevated
)

# Function to check if the current user has administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Function to validate path existence
function Test-PathExists {
    param (
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Host "Path '$Path' does not exist. Please provide a valid path." -ForegroundColor Red
        return $false
    }
    return $true
}

# Function to display progress bar
function Show-ProgressBar {
    Write-Host "Running..." -NoNewline
    for ($i = 1; $i -le 100; $i++) {
        Write-Progress -Activity "Progress" -Status "$i% Complete" -PercentComplete $i
        Start-Sleep -Milliseconds 250
    }
    Write-Host " Complete!" -ForegroundColor Green
}


# Ensure the existence of required folders
$UserName = Read-Host -Prompt " Enter UserName (eg. JDoe)"
$winFolderPath = "C:\Update1"
$msuFolderPath = "C:\Users\$UserName\Downloads"
$mountFolderPath = "C:\mountfolder1"

$requiredFolders = @($winFolderPath, $msuFolderPath, $mountFolderPath)
$requiredFolders | ForEach-Object {
    if (-not (Test-Path -Path $_ -PathType Container)) {
        Write-Host "Creating $_ folder..."
        New-Item -Path $_ -ItemType Directory | Out-Null
    }
}

# Check if the script is run with administrative privileges, if not, attempt to elevate
if ((Test-Admin) -eq $false) {
    if ($Elevated) {
        Write-Host "Failed to elevate permissions. Aborting." -ForegroundColor Red
    }
    else {
        Write-Host "Elevating permissions..."
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile", "-NoExit", "-File", "`"$($myinvocation.MyCommand.Definition)`"", "-Elevated")
    }
    exit
}

Write-Host "Running with full privileges"

# Predefined list of locations for selection
$wimLocations = @(
   	"\\Path\WinBase10\Pro Edition\22H2",
    "\\Path\backup$\WinBase10\Pro Edition\21H2",
    "\\Path\backup$\WinBase10\Ent Edition\22H2",
    "\\Path\backup$\WinBase10\Ent Edition\21H2",
	"\\Path\backup$\Win11\Enterprise\21H2",
	"\\Path\backup$\Win11\Enterprise\22H2",
	"\\Path\backup$\Win11\Enterprise\23H2",
	"\\Path\backup$\Win11\Pro\21H2",
	"\\Path\backup$\Win11\Pro\22H2",
	"\\Path\backup$\Win11\Pro\23H2"
	
	
   
)

# Present options to the user
Write-Host "Select the .wim file location:"
for ($i = 0; $i -lt $wimLocations.Count; $i++) {
    Write-Host "$($i + 1). $($wimLocations[$i])"
}
Write-Host "$($wimLocations.Count + 1). Enter a custom location"
$selectedLocationIndex = [int](Read-Host -Prompt "Enter the number corresponding to the .wim file location you want to use")

# Validate user input
if ($selectedLocationIndex -lt 1 -or $selectedLocationIndex -gt ($wimLocations.Count + 1)) {
    Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
    exit
}

if ($selectedLocationIndex -eq ($wimLocations.Count + 1)) {
    $wimfilelocation = Read-Host -Prompt "Enter the custom location path"
} else {
    $wimfilelocation = $wimLocations[$selectedLocationIndex - 1]
Write-Host "Selected path: $wimfilelocation"
Write-Host "Path exists: $(Test-Path $wimfilelocation)"	
}

# Prompt for necessary inputs
do {
    if (-not (Test-Path -Path $mountFolderPath)) {
        $mountFolderPath = Read-Host -Prompt "Please enter a valid path where you want to mount the file"
    }
} until (Test-Path -Path $mountFolderPath)

# Get the latest .wim file in the $wimfilelocation directory
$latestWimFile = Get-ChildItem -Path $wimfilelocation -Filter "*.wim" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$wim_Filename = $latestWimFile.BaseName
$Rename = Read-Host -Prompt "Rename updated file: Enter New wim filename (eg. Windows 10 22H2 XXXX.3456)"

# Set error action preference
$ErrorActionPreference = 'Stop'

# Display progress bar
Show-ProgressBar

try {
    # Copy .wim file to c:\win folder
    Copy-Item -Path $latestWimFile.FullName -Destination $winFolderPath -Force
    Write-Host "File copied "

    # Mount the Windows image
    mount-windowsimage -ImagePath "$winFolderPath\$wim_Filename.wim" -Index 1 -Path $mountFolderPath
    Write-Host "Image mounted successfully"

    # Add Windows package
    #$msuFilePath = Get-ChildItem -Path $msuFolderPath -Filter "*.msu" | Select-Object -ExpandProperty FullName
    $latestMsuFile = Get-ChildItem -Path $msuFolderPath -Filter "*.msu" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestMsuFile) {
        $msuFilePath = $latestMsuFile.FullName
        Write-Host "Latest .msu file found: $($latestMsuFile.Name)"
    } else {
        Write-Host "No .msu files found in the directory: $msuFolderPath" -ForegroundColor Red
        exit
    }
    add-windowspackage -PackagePath $msuFilePath -Path $mountFolderPath
    #add-windowspackage -PackagePath $latestMsuFile -Path $mountFolderPath

    Write-Host "Package added successfully"

    # Dismount the Windows image
    Dismount-WindowsImage -Path $mountFolderPath -Save
    Write-Host "Image unmounted successfully"

    # Rename the .wim file
    Rename-Item -Path "$winFolderPath\$wim_Filename.wim" -NewName "$Rename.wim"
    Write-Host "File renamed to $Rename"
    
    $backupdestinationfolder = "$wimfilelocation"

    # Copy the renamed file to the backup folder
    Copy-Item -Path $winFolderPath\$Rename.wim -Destination $backupdestinationfolder

    Write-Host "$Rename copied to the backup folder"

    # Delete the .wim file in the C:\win folder
    Remove-Item -Path $winFolderPath\$Rename.wim -Force
    Write-Host "Copy of wim File deleted from C drive"

} catch {
    Write-Host $_.Exception|format-list -force
    Write-Host $_.Exception.StackTrace
}

Write-Host "Script execution completed." -ForegroundColor Green

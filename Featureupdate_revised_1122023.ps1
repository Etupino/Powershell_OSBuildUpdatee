param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

'running with full privileges'

##### Mounting folder location######
$Mtfolder = Read-host -prompt "Please enter the path where you want to mount the file"
####
##### Cummulative update folder  location ######
$packagepath = Read-host -prompt "Please enter path/location of the update you want to add"
####
##### .Wim file location ######
$wimfilelocation = Read-host -prompt "please enter .wim file path/location"
$wimname = Read-Host -prompt "Enter .wim filename"
######

####
##### Rename .wim file ######
$Rename = Read-Host -prompt "Rename updated file: Enter New wim filename"

####
$backupdestinationfolder = Read-host -prompt " Saving to backup folder: Enter Destination backup folder"

####
$ErrorActionPreference = 'stop'
##### Show progress Bar######
 for ($i=1; $i -le 100; $i++) {
	Write-progress -Activity "Running >>>>" -status "$i% Complete:" -PercentComplete $i
	Start-sleep -Milliseconds 250
}
######
###############################
###############################
Write-Host "Seat back and relax! :)"
#####
#####
try {
	mount-windowsimage -imagepath "$wimfilelocation\$wimname.wim" -index:1 -path $Mtfolder; write-host "mounted successfully"


	add-windowspackage -Packagepath "$packagepath.msu" -path $mtfolder; write-host "package added successfully" 


	Dismount-WindowsImage -path $mtfolder -save;  write-host "unmounted successfully"


	Rename-item -path "$wimfilelocation\$wimname.wim" -newname "$Rename.wim"; write-host "file renamed to $Rename"


	Copy-item -path "$wimfilelocation\$Rename.wim" -destination "$backupdestinationfolder"; write-host "Great !!! $rename copied to the backup server"

}
catch {
	Write-Host -object "Ooooppps!An error occured"
	Write-Error $_
	}
####	
Write-host "All done! The fun ends here!!!"

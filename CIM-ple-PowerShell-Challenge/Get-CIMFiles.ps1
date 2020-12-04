Param(
    [Parameter(Mandatory=$true,Position=0)][String]$folderPath,
    [Parameter(Mandatory=$false,Position=1)][Boolean]$Recursive=$false,
    [Parameter(Mandatory=$false,Position=2)][Boolean]$showHidden=$false,
    [Parameter(Mandatory=$false,Position=3)][Boolean]$showCompressed=$false,
    [Parameter(Mandatory=$false,Position=4)][Boolean]$showEncrypted=$false
)

$Global:arrayElements = @()
$Global:Recurse = $Recursive
$Global:showHidden = $showHidden
$Global:showCompressed = $showCompressed
$Global:showEncrypted = $showEncrypted

function Get-CIMProperties
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)][object]$Element
    )

    foreach($row in $element){

        $mode = @('-','-','-','-','-','-')
        
        if ($Global:showHidden -eq $false -AND $row.Hidden -eq $true) { break }
        if ($Global:showCompressed -eq $false -AND $row.Compressed -eq $true) { break }
        if ($Global:showEncrypted -eq $false -AND $row.Encrypted -eq $true) { break }
        
        
        if ($row.FileType -eq 'File Folder'){ $mode[0] = 'd' }
        if ($row.Archive -eq $true){ $mode[1] = 'a' }
        if ($row.Writeable -eq $false){ $mode[2] = 'r' }
        if ($row.Hidden -eq $true){ $mode[3] = 'h' }

        if ($row.System -eq $true){ $mode[5] = 's' }

        $modeStr = $mode -join ''

        $myObject = [PSCustomObject]@{
            Mode     = $modeStr
            LastWriteTime = $row.LastModified
            Length = $row.FileSize
            Name    = $row.Name.Split('\')[-1]
        }
        $Global:arrayElements += $myObject

        if ($mode[0] = 'd' -AND $Global:Recurse -eq $true){ Get-CIMFolderFiles -Path $row.Name }

    }

}



function Get-CIMFolderFiles
{
    [CmdletBinding()]
    Param
    (
        [string]$Path
    )

    if ($Path.IndexOf('\\') -eq 0){
        $remoteServer = $Path.split('\')[2]
        $shareFolder = $Path.split('\')[3]
        $shareData = Get-CimInstance -ClassName Win32_Share -ComputerName $remoteServer -Filter "Name='$shareFolder'"

        $unitDrive = Split-Path -Path $shareData.Path -Qualifier
        $portionPath = Split-Path -Path $shareData.Path -NoQualifier
        
        $CIMFolder = ($portionPath.TrimEnd('\') + "\").Replace('\','\\')

        $data = (Get-CimInstance -Class Cim_LogicalFile -ComputerName $remoteServer -Filter "Drive='$unitDrive' and Path='$CIMFolder'")

    }else{
        $unitDrive = Split-Path -Path $path -Qualifier
        $portionPath = Split-Path -Path $path -NoQualifier
        $CIMFolder = $portionPath.Replace('\','\\')
        $CIMFolder = ($portionPath.TrimEnd('\') + "\").Replace('\','\\')

        $data = (Get-CimInstance -Class Cim_LogicalFile -Filter "Drive='$unitDrive' and Path='$CIMFolder'")
    }
    
    if ($data) { Get-CIMProperties -Element $data }
    
}

Get-CIMFolderFiles -Path $folderPath

$arrayElements | FT -AutoSize
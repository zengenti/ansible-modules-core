#!powershell
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# WANT_JSON
# POWERSHELL_COMMON

Function isBinaryFile($currFile) {
    # encoding variable
    $encoding = ""

    # Get the first 1024 bytes from the file
    $byteArray = Get-Content -Path $currFile -Encoding Byte -TotalCount 1024

    if( ("{0:X}{1:X}{2:X}" -f $byteArray) -eq "EFBBBF" )
    {
        # Test for UTF-8 BOM
        $encoding = "UTF-8"
    }
    elseif( ("{0:X}{1:X}" -f $byteArray) -eq "FFFE" )
    {
        # Test for the UTF-16
        $encoding = "UTF-16"
    }
    elseif( ("{0:X}{1:X}" -f $byteArray) -eq "FEFF" )
    {
        # Test for the UTF-16 Big Endian
        $encoding = "UTF-16 BE"
    }
    elseif( ("{0:X}{1:X}{2:X}{3:X}" -f $byteArray) -eq "FFFE0000" )
    {
        # Test for the UTF-32
        $encoding = "UTF-32"
    }
    elseif( ("{0:X}{1:X}{2:X}{3:X}" -f $byteArray) -eq "0000FEFF" )
    {
        # Test for the UTF-32 Big Endian
        $encoding = "UTF-32 BE"
    }

    if($encoding)
    {
        # File is text encoded
        return $false
    }

    # So now we're done with Text encodings that commonly have '0's
    # in their byte steams.  ASCII may have the NUL or '0' code in
    # their streams but that's rare apparently.

    # Both GNU Grep and Diff use variations of this heuristic

    if( $byteArray -contains 0 )
    {
        # Test for binary
        return $true
    }

    # This should be ASCII encoded 
    $encoding = "ASCII"

    return $false
}

$ErrorActionPreference = "Stop"

$params = Parse-Args $args -supports_check_mode $true

# diff_peek (needed for diff mode)
$diff_peek = Get-Attr $params "diff_peek" $FALSE
$check_mode = Get-AnsibleParam $params "_ansible_check_mode" -Default $false

# path
$path = Get-Attr $params "path" $FALSE
If ($path -eq $FALSE)
{
    $path = Get-Attr $params "dest" $FALSE
    If ($path -eq $FALSE)
    {
        $path = Get-Attr $params "name" $FALSE
        If ($path -eq $FALSE)
        {
            Fail-Json (New-Object psobject) "missing required argument: path"
        }
    }
}

# JH Following advice from Chris Church, only allow the following states
# in the windows version for now:
# state - file, directory, touch, absent
# (originally was: state - file, link, directory, hard, touch, absent)

$state = Get-Attr $params "state" "unspecified"
# if state is not supplied, test the $path to see if it looks like 
# a file or a folder and set state to file or folder

# result
$result = New-Object psobject @{
    changed = $FALSE
    path = $path
}

#Exit-Json $result

$path_exists = Test-Path $path

# short circuit for diff_peek
If ( $diff_peek )
{
    $appears_binary = $False
    $res_state = "absent"

    If($path_exists)
    {
        $res_state = "present"
        $appears_binary = isBinaryFile $Path
        $diff_info = Get-Item $path
        $result.size = $diff_info.Length
        $result.created_utc = $diff_info.CreationTimeUtc.ToString("s")
    }
    $result.appears_binary = $appears_binary
    $result.state  = $res_state
    Exit-Json $result
}


If ( $state -eq "touch" )
{
    if(-not $check_mode){
        If($path_exists)
        {
            (Get-ChildItem $path).LastWriteTime = Get-Date
        }
        Else
        {
            echo $null > $path
        }
        $touch_info = Get-Item $path
        $result.is_directory = $touch_info.PsIsContainer
        $result.size = $touch_info.Length
        $result.created_utc = $touch_info.CreationTimeUtc.ToString("s")    
    }

    $result.operation = 'touch'
    $result.changed = $TRUE
    Exit-Json $result
}

If ($path_exists)
{
    $fileinfo = Get-Item $path
    If ( $state -eq "absent" )
    {   
        if(-not $check_mode){
            Remove-Item -Recurse -Force $fileinfo
        }
        $result.operation = 'absent' 
        $result.changed = $TRUE

    }
    Else
    {
        If ( $state -eq "directory" -and -not $fileinfo.PsIsContainer )
        {
            Fail-Json (New-Object psobject) "path is not a directory"
        }

        If ( $state -eq "file" -and $fileinfo.PsIsContainer )
        {
            Fail-Json (New-Object psobject) "path is not a file"
        }
    }
}
Else
# doesn't yet exist
{
    If ( $state -eq "unspecified" )
    {
        $basename = Split-Path -Path $path -Leaf
        If ($basename.length -gt 0) 
        {
           $state = "file"
        }
        Else
        {
           $state = "directory"
        }
    }

    If ( $state -eq "directory" )
    {
        if(-not $check_mode){
            $dir_info = New-Item -ItemType directory -Path $path
        }
        #$result.is_directory = $dir_info.PsIsContainer
        #$result.size = $dir_info.Length
        $result.created_utc = $dir_info.CreationTimeUtc.ToString("s")
        $result.operation = 'directory'
        $result.changed = $TRUE
    }

    If ( $state -eq "file" )
    {
        Fail-Json (New-Object psobject) "path will not be created"
    }
}

Exit-Json $result


# Taken from http://stackoverflow.com/questions/1077634/powershell-search-script-that-ignores-binary-files, after some basic research this seemed like a reasonable solution.

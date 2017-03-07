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

$params = Parse-Args $args $true;

$src = Get-Attr $params "src" (Get-Attr $params "path" $FALSE);
If (-not $src)
{
    Fail-Json (New-Object psobject) "missing required argument: src";
}

If (Test-Path -PathType Leaf $src)
{
    $bytes = [System.IO.File]::ReadAllBytes($src);

    $containsBOM = $FALSE
    if ($bytes.Length -gt 2 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){
        $containsBOM = $TRUE
        $content = [System.Convert]::ToBase64String($bytes[3..($bytes.length -3)]);
    }
    Elseif ($bytes.Length -gt 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE){
        $containsBOM = $TRUE
        $content = [System.Convert]::ToBase64String($bytes[2..($bytes.length)]);
    }
    Else{
        $containsBOM = $FALSE
        $content = [System.Convert]::ToBase64String($bytes);    
    }
    #$content = [System.Convert]::ToBase64String($bytes);    
    
    $result = New-Object psobject @{
        changed = $false
        encoding = "base64"
        content = $content
        contained_bom = $containsBOM
        src = $src
    };
    Exit-Json $result;
}
ElseIf (Test-Path -PathType Container $src)
{
    Fail-Json (New-Object psobject) ("is a directory: " + $src);
}
Else
{
    Fail-Json (New-Object psobject) ("file not found: " + $src);
}

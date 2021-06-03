function Get-SQL()
{
    param(
        [Parameter(mandatory=$true)][string]$SQLQuery,
        [parameter(mandatory=$true)][string]$SQLServer,
        [parameter(mandatory=$true)][string]$Database,
        [parameter(mandatory=$true)][string]$UserName,
        [parameter(mandatory=$true)][string]$Password
    )
    try{
        $connectionString = “Server=$SQLServer;Database=$Database;User=$UserName;Password=$Password;Integrated Security=False;”
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString


        
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $SQLQuery
        $data = $command.ExecuteReader()
        $result = New-Object System.Data.DataTable
        $result.Load($data)
        
        if ($result.Rows.Count -eq 0){throw "Query:`n $query `n`nReturned no results."}
        
        $connection.Close()               
        return $result
    }
    catch
    {
        $connection.Close()
        Write-Warning $_
        return $null
    }
}

function getID ($cert){
    if($cert){
        $result = Get-SQL -SQLQuery "SELECT id, CentralInstanceId FROM RiskManagement.Brokers where SubjectName='$cert'" -SQLServer "NoneOfYourBussiness" -Database "NoneOfYourBussiness" -Username "NoneOfYourBussiness" -Password "NoneOfYourBussiness"
    }
    if(!(($result.id) -is [system.array])){
        $returnObj = [PSCustomObject]@{
            ID = @($result.id)
            CentralID = @($result.CentralInstanceId)
        }
    }
    else{
        $returnObj = [PSCustomObject]@{
            ID = $result.id
            CentralID = $result.CentralInstanceId
        }
    }
    
    return $returnObj
}


function ExtractBrand($service){
    return ($service.PathName  -split "-config ")[1]
}
function DitermenCurrFolder($service , $Root , $brand){
    $path = ($service.PathName -split ".exe")[0]
    $path = split-path $path
    $leaf = split-path $path -Leaf
    return "$Root\$leaf\$brand"
}
Function ExtractAttFromSysSettings($RawXML){
    if(!$RawXML){return}
    $SystemSettingsStateObj = ([xml]$RawXML).ChildNodes
    return $SystemSettingsStateObj.CertificateSubjectName
}

function ExtractAttFromApiConfig($RawXML){
    if(!$RawXML){return}
    $ApiConfigObj = ((([xml]$RawXML).ChildNodes).object).ChildNodes
    $value = $ApiConfigObj.value -split "`n"
    $name = $ApiConfigObj.name -split "`n"
    $groupIndex
    $computerIndex
    $count = 0
    foreach($line in $name){
        if($line -like "Groups"){$groupIndex = $count}
        if($line -like "ComputerName"){$computerIndex =$count}

        $count++
    }

    $returnObj = [PSCustomObject]@{
        coumputerName = $value[$computerIndex]
        Group = $value[$groupIndex]
    }
    
    return $returnObj
}

$ip = "NoneOfYourBussiness"
$rootFolder = "\\$ip\C`$\Program Files (x86)\Leverate"
$services = Get-WmiObject win32_service -ComputerName $ip | where {$_.State -like "Running" -and $_.Name -match "LeverateRMS"}
$ObjectForJsonFile = @()

foreach($service in $services){
    $brand = ExtractBrand $service
    $currFolder = DitermenCurrFolder $service $rootFolder $brand
    $SystemSettingsStateRaw = Get-Content "$currFolder\SystemSettingsState.xml" -ErrorAction SilentlyContinue
    $ApiConfigRaw = Get-Content "$currFolder\TradesProvidersPlugins\MetaTraderAPIConfiguration.xml" -ErrorAction SilentlyContinue
    $Certificate = ExtractAttFromSysSettings $SystemSettingsStateRaw
    $SQLQueryresult = getID $Certificate 
    $IDs = $SQLQueryresult.id
    $centralInstanceIDs = $SQLQueryresult.CentralID
    $ApiConfigObj = ExtractAttFromApiConfig $ApiConfigRaw
    $count = 0
    foreach($id in $IDs){
        
        $pushToJsonObj = [PSCustomObject]@{
            name = $brand
            groups = $ApiConfigObj.Group
            ComputerName = $ApiConfigObj.coumputerName
            ID = [String]$id
            CentralInstanceId = [String]$centralInstanceIDs[0]
        }
        $ObjectForJsonFile += $pushToJsonObj
        $count++
    }
}
Clear-Content "data.js"
Add-Content "data.js" -value "let data = "
Add-Content "data.js" -value ($ObjectForJsonFile | ConvertTo-Json)



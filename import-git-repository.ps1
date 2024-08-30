# Variables
$Organization = "YOUR-AZURE-DEVOPS-ORGANIZATION"
$ProjectName = "YOUR-PROJECT-NAME"
$PAT = "YOUR-PERSONAL-ACCESS-TOKEN"
$gitHubRepoUrl = "https://github.com/YOUR-GIT-REPO-URL/TO-BE-IMPORTED.git" # The URL of the Git repository to import
$repositoryName = "YOUR-REPOSITORY-NAME"  # The name of the repository to create in Azure DevOps

# Create Authorization Header
$ADOAuthHeader = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)"))
}

# Get Project ID dynamically from Azure DevOps
$projectUrl = "https://dev.azure.com/$Organization/_apis/projects?api-version=6.0"
$projectResponse = Invoke-RestMethod -Uri $projectUrl -Method Get -Headers $ADOAuthHeader

$ProjectID = ($projectResponse.value | Where-Object { $_.name -eq $ProjectName }).id

# Check if Project ID is retrieved
if (-not $ProjectID) {
    Write-Host "Failed to retrieve the Project ID. Please check the Project Name and try again."
    exit
}

Write-Host "Project ID retrieved: $ProjectID"

# Create Repository in Azure DevOps
$createRepoUrl = "https://dev.azure.com/$Organization/$ProjectName/_apis/git/repositories?api-version=6.0"
$repoBody = @{
    name    = $repositoryName
    project = @{
        id = $ProjectID
    }
} | ConvertTo-Json

$createResponse = Invoke-RestMethod -Uri $createRepoUrl -Method Post -Body $repoBody -ContentType "application/json" -Headers $ADOAuthHeader

# Check if Repository is created
if ($createResponse -and $createResponse.id) {
    $createdRepoId = $createResponse.id
    Write-Host "Repository created with ID: $createdRepoId"
}
else {
    Write-Host "Failed to create the repository. Please check the API request and permissions."
    exit
}

# Validate Repository Import
$validationUrl = "https://dev.azure.com/$Organization/$ProjectName/_apis/git/import/ImportRepositoryValidations?api-version=6.0"
$validationBody = @{
    gitSource = @{
        url = $gitHubRepoUrl
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri $validationUrl -Method Post -Body $validationBody -ContentType "application/json" -Headers $ADOAuthHeader
Write-Host "Repository import validation completed."

# Send Repository Import Request
$importUrl = "https://dev.azure.com/$Organization/$ProjectName/_apis/git/repositories/$createdRepoId/importRequests?api-version=6.0"
$importBody = @{
    parameters = @{
        gitSource = @{
            url = $gitHubRepoUrl
        }
    }
} | ConvertTo-Json

$ImportResponse = Invoke-RestMethod -Uri $importUrl -Method Post -Body $importBody -ContentType "application/json" -Headers $ADOAuthHeader

if ($ImportResponse) {
    Write-Host "Repository import request sent successfully."
}
else {
    Write-Host "Failed to send repository import request."
    exit
}

# Check Import Status
$importStatusUrl = "https://dev.azure.com/$Organization/$ProjectName/_apis/git/repositories/$createdRepoId/importRequests?api-version=6.0"
$importStatusResponse = Invoke-RestMethod -Uri $importStatusUrl -Method Get -Headers $ADOAuthHeader

if ($importStatusResponse -and $importStatusResponse.value) {
    $importStatus = $importStatusResponse.value | Select-Object -Last 1
    Write-Host "Import Status: $($importStatus.status)"
}
else {
    Write-Host "Failed to retrieve import status or import status is empty."
}
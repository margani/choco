param(
    # The command to test.
    [string[]]$Command = @(
        "apikey"
        "setapikey"
    )
)

Import-Module helpers/common-helpers

Describe "choco <_>" -ForEach $Command -Tag Chocolatey, ApiKeyCommand {
    BeforeAll {
        Remove-NuGetPaths
        Initialize-ChocolateyTestInstall
        $CurrentCommand = $_

        $expectedLicenseHeader = Get-ExpectedChocolateyHeader
    }

    AfterAll {
        Remove-ChocolateyTestInstall
    }

    Context "Running $CurrentCommand with no sources configured" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Only displays chocolatey name with version" {

            $Output.String | Should -Match "(?m)^$expectedLicenseHeader(\s*|\s*Chocolatey is not an official build.*)$"
        }
    }

    # Even though v1.x does not support explicit list command, it still functions as expected.
    # As such we keep this test here to be comparable with v2.x
    Context "Running $CurrentCommand list with no sources configured" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand list
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Only displays chocolatey name with version" {

            $Output.String | Should -Match "(?m)^$expectedLicenseHeader(\s*|\s*Chocolatey is not an official build.*)$"
        }
    }

    Context "Running $CurrentCommand with no sources configured with source parameter" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand --source "https://not-existing.test.com/api"
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Only displays chocolatey name with version" {
            $Output.String | Should -Match "(?m)^$expectedLicenseHeader(\s*|\s*Chocolatey is not an official build.*)$"
        }
    }

    # Even though v1.x does not support explicit list command, it still functions as expected.
    # As such we keep this test here to be comparable with v2.x
    Context "Running $CurrentCommand list with no sources configured with source parameter" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand list --source "https://not-existing.test.com/api"
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Only displays chocolatey name with version" {
            $Output.String | Should -Match "(?m)^$expectedLicenseHeader(\s*|\s*Chocolatey is not an official build.*)$"
        }
    }

    Context "Add single api key" -ForEach @(
        @{
            Key    = '--key'
            Source = '--source'
        }
        @{
            Key    = '--apikey'
            Source = '--source'
        }
        @{
            Key    = '--api-key'
            Source = '--source'
        }
        @{
            Key    = '-k'
            Source = '-s'
        }) {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand $Key "test-api" $Source "https://test.com/api/$($Key)"

            $ConfigFileContent = [xml](Get-Content $env:ChocolateyInstall\config\chocolatey.config)
            $apiKeys = @($ConfigFileContent.chocolatey.apiKeys.apiKeys)
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with the key being added" {
            $Output.Lines | Should -Contain "Added apiKey for https://test.com/api/$($Key)"
        }

        It "Adds the apikey in the file" {
            $key = $Key
            $config = $apiKeys.Where{ $_.source -eq "https://test.com/api/$key" }
            $config | Should -HaveCount 1
            $config.key | Should -Not -BeNullOrEmpty # The key is encryped, so we don't test the value
        }
    }

    Context "Update single api key" -ForEach @(
        @{
            Key    = '--key'
            Source = '--source'
        }
        @{
            Key    = '--apikey'
            Source = '--source'
        }
        @{
            Key    = '--api-key'
            Source = '--source'
        }
        @{
            Key    = '-k'
            Source = '-s'
        }) {
        BeforeAll {
            # Make sure an API Key already exist
            $null = Invoke-Choco $CurrentCommand --key "test-old" --source "https://test.com/api/$($Key)"

            $Output = Invoke-Choco $CurrentCommand $Key "test-api-updated" $Source "https://test.com/api/$($Key)"

            $ConfigFileContent = [xml](Get-Content $env:ChocolateyInstall\config\chocolatey.config)
            $apiKeys = @($ConfigFileContent.chocolatey.apiKeys.apiKeys)
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with the key being added" {
            $Output.Lines | Should -Contain "Updated apiKey for https://test.com/api/$($Key)"
        }

        # Skipping for now, may need to read the file twice to compare the values
        It "Adds the apikey in the file" -Skip {
            $key = $Key
            $config = $apiKeys.Where{ $_.source -eq "https://test.com/api/$key" }
            $config | Should -HaveCount 1
            $config.key | Should -Not -BeNullOrEmpty # The key is encryped, so we don't test the value
        }
    }

    Context "Remove single api key" -ForEach @(
        '--rem'
        '--remove'
    ) {
        BeforeAll {
            # Make sure an API Key already exist
            $null = Invoke-Choco $CurrentCommand --key "test-removal" --source "https://remove.test.com/api"

            $Output = Invoke-Choco $CurrentCommand --source "https://remove.test.com/api" $_

            $ConfigFileContent = [xml](Get-Content $env:ChocolateyInstall\config\chocolatey.config)
            [array]$apiKeys = $ConfigFileContent.chocolatey.apiKeys.apiKeys
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with the key being removed" {
            $Output.Lines | Should -Contain "Removed ApiKey for https://remove.test.com/api"
        }

        It "Displays a deprecation warning about --rem/--remove" {
            $message = "The --rem / --remove option is deprecated and will be removed in v2.0.0."
            $Output.Lines | Should -Contain $message -Because "--remove is being deprecated in v2.0.0."
        }

        # Skipping for now, may need to read the file twice to compare the values
        It "Removed apikey do not exist in file" -Skip {
            $config = $apiKeys.Where{ $_.source -eq "https://remove.test.com/api" }
            $config | Should -BeNullOrEmpty
        }
    }

    Context "Remove non-existing api key" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand --source "https://non-existing.test.com/api" --remove
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with ApiKey not found" {
            $Output.Lines | Should -Contain "ApiKey was not found for https://non-existing.test.com/api"
        }
    }

    Context "Remove api key without specifying source" {
        BeforeAll {
            $Output = Invoke-Choco $CurrentCommand --key "some-key" --remove
        }

        It "Exits with Failure (1)" {
            $Output.ExitCode | Should -Be 1
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message about source being required" {
            $Output.Lines | Should -Contain "You must specify 'source' to remove an API key."
        }
    }

    Context "Returns configured apikey source by source name" {
        BeforeAll {
            $null = Invoke-Choco $CurrentCommand --key "test-api-key" --source "https://test.com/api"

            $Output = Invoke-Choco $CurrentCommand --source "https://test.com/api"
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with the configured apikey" {
            $Output.Lines | Should -Contain "https://test.com/api - (Authenticated)"
        }
    }

    # Even though v1.x does not support explicit list command, it still functions as expected.
    # As such we keep this test here to be comparable with v2.x
    Context "Returns configured apikey source by source name with list subcommand" {
        BeforeAll {
            $null = Invoke-Choco $CurrentCommand --key "test-api-key" --source "https://test.com/api"
            $null = Invoke-Choco $CurrentCommand --key "test-api-key" --source "https://test.com/api/2"

            $Output = Invoke-Choco $CurrentCommand list --source "https://test.com/api"
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays chocolatey name with version" {
            $Output.Lines | Should -Contain $expectedLicenseHeader
        }

        It "Displays a message with the configured apikey" {
            $Output.Lines | Should -Contain "https://test.com/api - (Authenticated)"
            $Output.Lines | Should -Not -Contain "https://test.com/api/2 - (Authenticated)"
        }
    }

    # This needs to be the last test in this block, to ensure NuGet configurations aren't being created.
    Test-NuGetPaths
}

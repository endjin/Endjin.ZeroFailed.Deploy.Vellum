# <copyright file="Get-SWACustomDomainValidationToken.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Import the function under test
    . $PSScriptRoot\Get-SWACustomDomainValidationToken.ps1
}

Describe 'Get-SWACustomDomainValidationToken' {
    
    Context 'When custom domain exists with validation token' {

        It 'Should return the validation token immediately' {
            Mock Get-AzStaticWebAppCustomDomain {
                return [PSCustomObject]@{
                    Domain = 'test.com'
                    ValidationToken = 'abc123token'
                }
            }

            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            $result | Should -Be 'abc123token'
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 1 -ParameterFilter {
                                                                        $ResourceGroupName -eq 'test-rg' -and
                                                                        $Name -eq 'test-swa' -and
                                                                        $DomainName -eq 'test.com' }
        }
    }

    Context 'When custom domain does not exist' {
        
        BeforeEach {
            Mock Get-AzStaticWebAppCustomDomain { return $null }
            Mock Write-Information {}
        }

        It 'Should return null when custom domain is not configured' {
            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            $result | Should -BeNullOrEmpty
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 1
        }

        It 'Should write information message when domain not found' {
            $informationMessages = @()
            Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            Should -Invoke Write-Information -ParameterFilter { $MessageData -eq "The site 'test-swa' is not configured with the custom domain 'test.com'" }
        }
    }

    Context 'When custom domain exists but validation token is initially empty' {
        
        It 'Should poll until token becomes available' {
            # First call returns empty token, second call returns token
            Mock Get-AzStaticWebAppCustomDomain {
                if ($script:CallCount -eq $null) { $script:CallCount = 0 }
                $script:CallCount++
                
                if ($script:CallCount -eq 1) {
                    return [PSCustomObject]@{
                        Domain = 'test.com'
                        ValidationToken = ''
                    }
                } else {
                    return [PSCustomObject]@{
                        Domain = 'test.com'
                        ValidationToken = 'delayed-token-123'
                    }
                }
            }
            
            Mock Start-Sleep { }  # Speed up the test
            
            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -PollingIntervalSeconds 1
            
            $result | Should -Be 'delayed-token-123'
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 2
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 1 }
            
            # Clean up script variable
            Remove-Variable -Name CallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Should respect custom polling interval' {
            Mock Get-AzStaticWebAppCustomDomain {
                return [PSCustomObject]@{
                    Domain = 'test.com'
                    ValidationToken = ''
                }
            }
            
            Mock Start-Sleep { }
            
            { Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -PollingIntervalSeconds 30 -MaxPollingAttempts 2 } | 
                Should -Throw
            
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 30 }
        }
    }

    Context 'When maximum polling attempts are exceeded' {
        
        BeforeEach {
            Mock Get-AzStaticWebAppCustomDomain {
                return [PSCustomObject]@{
                    Domain = 'test.com'
                    ValidationToken = $null  # Always null/empty
                }
            }
            Mock Start-Sleep { }  # Speed up the test
        }

        It 'Should throw exception when max attempts exceeded' {
            { Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -MaxPollingAttempts 3 } | 
                Should -Throw -ExpectedMessage "*validation token could not be retrieved after 3 attempts*"
        }

        It 'Should call Azure API the correct number of times' {
            { Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -MaxPollingAttempts 2 } | 
                Should -Throw
            
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 2
        }

        It 'Should sleep between attempts but not after the last attempt' {
            { Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -MaxPollingAttempts 3 -PollingIntervalSeconds 1 } | 
                Should -Throw
            
            # Should sleep 2 times (between attempts 1-2 and 2-3, but not after attempt 3)
            Should -Invoke Start-Sleep -Times 2 -ParameterFilter { $Seconds -eq 1 }
        }
    }

    Context 'When Azure API throws exceptions' {
        
        It 'Should handle and retry on API exceptions' {
            Mock Get-AzStaticWebAppCustomDomain {
                if ($script:ApiCallCount -eq $null) { $script:ApiCallCount = 0 }
                $script:ApiCallCount++
                
                if ($script:ApiCallCount -eq 1) {
                    throw "Azure API Error"
                } else {
                    return [PSCustomObject]@{
                        Domain = 'test.com'
                        ValidationToken = 'recovered-token'
                    }
                }
            }
            
            Mock Start-Sleep { }
            Mock Write-Warning {}
            
            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            $result | Should -Be 'recovered-token'
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 2
            
            # Clean up script variable
            Remove-Variable -Name ApiCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Should throw exception when all retry attempts fail' {
            Mock Get-AzStaticWebAppCustomDomain { throw "Persistent Azure API Error" }
            Mock Start-Sleep { }
            Mock Write-Warning {}
            
            { Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -MaxPollingAttempts 2 } | 
                Should -Throw -ExpectedMessage "*validation token could not be retrieved after 2 attempts*"
        }

        It 'Should write warning messages for caught exceptions' {
            Mock Get-AzStaticWebAppCustomDomain { throw "Test Exception" }
            Mock Start-Sleep { }
            Mock Write-Warning {}
            
            $warningMessages = @()
            {
                Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -MaxPollingAttempts 1
            } | Should -Throw
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*Error occurred while retrieving custom domain information on attempt 1*Test Exception*" }
        }
    }

    Context 'Integration scenarios' {

        BeforeEach {
            Mock Write-Warning {}
        }
        
        It 'Should handle mixed scenarios: exception then empty token then success' {
            Mock Get-AzStaticWebAppCustomDomain {
                if ($script:MixedCallCount -eq $null) { $script:MixedCallCount = 0 }
                $script:MixedCallCount++
                
                switch ($script:MixedCallCount) {
                    1 { throw "Temporary API Error" }
                    2 { 
                        return [PSCustomObject]@{
                            Domain = 'test.com'
                            ValidationToken = ''
                        }
                    }
                    default { 
                        return [PSCustomObject]@{
                            Domain = 'test.com'
                            ValidationToken = 'final-success-token'
                        }
                    }
                }
            }
            
            Mock Start-Sleep { }
            
            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            $result | Should -Be 'final-success-token'
            Should -Invoke Get-AzStaticWebAppCustomDomain -Times 3
            Should -Invoke Start-Sleep -Times 2  # Once after exception, once after empty token
            
            # Clean up script variable
            Remove-Variable -Name MixedCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Should work with default parameter values' {
            Mock Get-AzStaticWebAppCustomDomain {
                return [PSCustomObject]@{
                    Domain = 'test.com'
                    ValidationToken = 'default-params-token'
                }
            }
            
            $result = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com'
            
            $result | Should -Be 'default-params-token'
        }
    }

    Context 'Verbose output validation' {
        
        It 'Should write appropriate verbose messages during polling' {
            Mock Get-AzStaticWebAppCustomDomain {
                return [PSCustomObject]@{
                    Domain = 'test.com'
                    ValidationToken = 'immediate-token'
                }
            }
            
            $res = Get-SWACustomDomainValidationToken -ResourceGroupName 'test-rg' -Name 'test-swa' -Domain 'test.com' -Verbose 4>&1
            
            $res[0] | Should -Be "Starting to poll for custom domain validation token for domain 'test.com' on Static Web App 'test-swa'"
            $res[1] | Should -Be "Polling attempt 1 of 8"
            $res[2] | Should -Be "Custom domain validation token for site 'test-swa' and domain 'test.com' found on attempt 1"
            $res[3] | Should -Be "immediate-token"
        }
    }
}

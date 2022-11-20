#region Configurable Variables

    <#
        .NOTES
        Use this section to configure testing variables. IE if the number of tabs change in the GUI update that variable here.
        All variables need to be global to be passed between contexts

    #>

    $global:FormName = "Chris Titus Tech's Windows Utility"

#endregion Configurable Variables

#region Load Variables needed for testing

    #Config Files

    #GUI
    $global:inputXML = get-content MainWindow.xaml
    $global:inputXML = $global:inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
    [xml]$global:XAML = $global:inputXML
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    $global:reader = (New-Object System.Xml.XmlNodeReader $global:xaml) 
    $global:Form  = [Windows.Markup.XamlReader]::Load( $global:reader )
    $global:xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name "Global:WPF$($_.Name)" -Value $global:Form.FindName($_.Name) -Scope global }

    #Variables to compare GUI to config files
    $Global:GUIFeatureCount = ( $global:configs.feature.psobject.members | Where-Object {$psitem.MemberType -eq "NoteProperty"}).count
    $Global:GUIApplicationCount = ($global:configs.applications.install.psobject.members | Where-Object {$psitem.MemberType -eq "NoteProperty"}).count
    $Global:GUITweaksCount = ($global:configs.tweaks.psobject.members | Where-Object {$psitem.MemberType -eq "NoteProperty"}).count

    #dotsource original script to pull in all variables and ensure no errors
    $script = Get-Content .\winutil.ps1
    $script[0..($script.count - 3)] | Out-File .\pester.ps1    

#endregion Load Variables needed for testing 

#===========================================================================
# Tests - Config Files
#===========================================================================

Describe "Config Files" {
    BeforeEach {
        $configs = @{}

        (
            "applications"
        ) | ForEach-Object {
            $configs["$PSItem"] = Get-Content .\config\$PSItem.json | ConvertFrom-Json
        }
    }
    Context "Application installs" {
        It "Imports with no errors" {
            $configs.Applications | should -Not -BeNullOrEmpty
        }
        $configs.applications.install | Get-Member -MemberType NoteProperty  | ForEach-Object {
            $TestCase = @{ name = $psitem.name }
            It "$($psitem.name) should include Winget Install" -TestCases $TestCase{
                param($name)
                $null -eq $configs.applications.install.$name.winget | should -Befalse -because "$name Did not include a Winget Install"
            } 
        }
    } 
}

#===========================================================================
# Tests - GUI
#===========================================================================

Describe "GUI" {
    Context "XML" {
        It "Imports with no errors" {
            $global:XAML | should -Not -BeNullOrEmpty
        }
        It "Title should be $global:FormName" {
            $global:XAML.window.Title | should -Be $global:FormName
        }
    }

    Context "Form" {
        It "Imports with no errors" {
            $global:Form | should -Not -BeNullOrEmpty
        }
        It "Title should match XML" {
            $global:Form.title | should -Be $global:XAML.window.Title
        }
        It "Features should be $Global:GUIFeatureCount" {
            (get-variable | Where-Object {$psitem.name -like "*feature*" -and $psitem.value.GetType().name -eq "CheckBox"}).count | should -Be $Global:GUIFeatureCount
        }
        It "Applications config should contain an application for each GUI checkbox" {

            $GUIApplications = (get-variable | Where-Object {$psitem.name -like "*install*" -and $psitem.value.GetType().name -eq "CheckBox"}).name -replace 'Global:',''
            $ConfigApplications = ($global:configs.applications.install.psobject.members | Where-Object {$psitem.MemberType -eq "NoteProperty"}).name

            Compare-Object -ReferenceObject $GUIApplications -DifferenceObject $ConfigApplications | Where-Object {$_.SideIndicator -eq "<="} | Select-Object -ExpandProperty InputObject | should -BeNullOrEmpty -Because "Config is missing applications"
        }
    } 
}

#===========================================================================
# Tests - GUI Functions
#===========================================================================

Describe "GUI Functions" {
    BeforeEach -Scriptblock {. ./pester.ps1}

    It "GUI should load with no errors" {
        $WPFTab1BT | should -Not -BeNullOrEmpty
        $WPFundoall | should -Not -BeNullOrEmpty
        $WPFPanelDISM | should -Not -BeNullOrEmpty
        $WPFPanelAutologin | should -Not -BeNullOrEmpty
        $WPFUpdatesdefault | should -Not -BeNullOrEmpty
        $WPFFixesUpdate | should -Not -BeNullOrEmpty
        $WPFUpdatesdisable | should -Not -BeNullOrEmpty
        $WPFUpdatessecurity | should -Not -BeNullOrEmpty
        $WPFFeatureInstall | should -Not -BeNullOrEmpty
        $WPFundoall | should -Not -BeNullOrEmpty
        $WPFDisableDarkMode | should -Not -BeNullOrEmpty
        $WPFEnableDarkMode | should -Not -BeNullOrEmpty
        $WPFtweaksbutton | should -Not -BeNullOrEmpty
        $WPFminimal | should -Not -BeNullOrEmpty
        $WPFlaptop | should -Not -BeNullOrEmpty
        $WPFdesktop | should -Not -BeNullOrEmpty
        $WPFInstallUpgrade | should -Not -BeNullOrEmpty
        $WPFinstall | should -Not -BeNullOrEmpty
    }

    It "Get-CheckBoxes Install should return data" {
        $WPFInstallvc2015_32.ischecked = $true
        (Get-CheckBoxes -Group WPFInstall) | should -Not -BeNullOrEmpty
        $WPFInstallvc2015_32.ischecked | should -be $false
    }
}

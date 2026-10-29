<#
====================================================================================================
AVGOL COPY MASTER - REPLICATION CONFIGURATOR & TASK INSTALLER (GUI)
====================================================================================================
Description:
A modern, standalone Windows WPF GUI to configure multi-folder SMB replication,
test network credentials, generate production-ready Robocopy scripts, and
create Windows Scheduled Tasks in a single click.

100% Air-Gap Compatible: Zero internet or third-party dependencies required.
====================================================================================================
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Avgol Copy Master"
    Width="940" Height="780"
    MinWidth="820" MinHeight="660"
    WindowStartupLocation="CenterScreen"
    Background="#18181f"
    Foreground="#f0f0f5"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Card Style -->
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#22222b"/>
            <Setter Property="BorderBrush" Value="#343442"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="7"/>
            <Setter Property="Padding" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>

        <!-- Section Header Style -->
        <Style x:Key="SectionHeader" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#58a6ff"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>

        <!-- Field Label Style -->
        <Style x:Key="FieldLabel" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#b0b0c0"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Margin" Value="0,0,0,4"/>
        </Style>

        <!-- Dark TextBox Style -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#121216"/>
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="BorderBrush" Value="#3e3e4f"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="7,4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>

        <!-- Dark PasswordBox Style -->
        <Style TargetType="PasswordBox">
            <Setter Property="Background" Value="#121216"/>
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="BorderBrush" Value="#3e3e4f"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="7,4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>

        <!-- Button Base -->
        <Style x:Key="BaseButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>

        <!-- Primary Action Button -->
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#0969da"/>
            <Setter Property="Foreground" Value="#ffffff"/>
        </Style>

        <!-- Success Button -->
        <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#238636"/>
            <Setter Property="Foreground" Value="#ffffff"/>
        </Style>

        <!-- Secondary Outline Button -->
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#2d2d3a"/>
            <Setter Property="Foreground" Value="#d0d0df"/>
            <Setter Property="BorderBrush" Value="#454558"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>

        <!-- Danger Button -->
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#b62324"/>
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="Padding" Value="8,3"/>
            <Setter Property="FontSize" Value="10"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="130"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Grid Grid.Row="0" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <TextBlock Text="Avgol Copy Master" FontSize="18" FontWeight="Bold" Foreground="#ffffff"/>
                <TextBlock Text="Configure multi-folder Robocopy synchronization and Windows Task Scheduler" FontSize="11" Foreground="#8b949e" Margin="0,2,0,0"/>
            </StackPanel>
            <Button x:Name="btnLoadConfig" Grid.Column="1" Content="Reload From Local Script" Style="{StaticResource SecondaryButton}" Height="30" VerticalAlignment="Center"/>
        </Grid>

        <!-- Scrollable Cards -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,8,0">
            <StackPanel>
                <!-- Card 1: SMB Authentication -->
                <Border Style="{StaticResource CardBorder}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Text="1. SOURCE SMB AUTHENTICATION" Style="{StaticResource SectionHeader}"/>

                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1.4*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Username -->
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Username (e.g. 10.91.13.204\admin)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtUsername" Height="30" Text="10.91.13.204\admin"/>
                            </StackPanel>

                            <!-- Password -->
                            <StackPanel Grid.Column="2">
                                <Grid>
                                    <TextBlock Text="Password" Style="{StaticResource FieldLabel}"/>
                                    <CheckBox x:Name="chkShowPassword" Content="Show" HorizontalAlignment="Right" Foreground="#8b949e" FontSize="10"/>
                                </Grid>
                                <Grid>
                                    <PasswordBox x:Name="txtPassword" Height="30"/>
                                    <TextBox x:Name="txtPasswordPlain" Height="30" Visibility="Collapsed"/>
                                </Grid>
                            </StackPanel>

                            <!-- Test SMB Button -->
                            <StackPanel Grid.Column="4">
                                <TextBlock Text="Connectivity" Style="{StaticResource FieldLabel}"/>
                                <Button x:Name="btnTestSmb" Content="Test SMB Connection" Style="{StaticResource SecondaryButton}" Height="30"/>
                            </StackPanel>
                        </Grid>
                    </Grid>
                </Border>

                <!-- Card 2: Folder Mappings -->
                <Border Style="{StaticResource CardBorder}">
                    <StackPanel>
                        <Grid Margin="0,0,0,8">
                            <TextBlock Text="2. FOLDER MAPPINGS (SOURCE UNC -> LOCAL DESTINATION)" Style="{StaticResource SectionHeader}" VerticalAlignment="Center"/>
                            <TextBlock x:Name="lblMappingCount" Text="0 Mappings" Foreground="#8b949e" FontSize="11" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                        </Grid>

                        <!-- DataGrid of Mappings -->
                        <DataGrid x:Name="dgMappings"
                                  Height="160"
                                  AutoGenerateColumns="False"
                                  CanUserAddRows="False"
                                  CanUserDeleteRows="False"
                                  IsReadOnly="True"
                                  SelectionMode="Single"
                                  Background="#141419"
                                  RowBackground="#18181f"
                                  AlternatingRowBackground="#1e1e26"
                                  Foreground="#ffffff"
                                  BorderBrush="#383848"
                                  GridLinesVisibility="Horizontal"
                                  HorizontalGridLinesBrush="#2a2a38"
                                  HeadersVisibility="Column"
                                  Margin="0,0,0,10">
                            <DataGrid.ColumnHeaderStyle>
                                <Style TargetType="DataGridColumnHeader">
                                    <Setter Property="Background" Value="#121216"/>
                                    <Setter Property="Foreground" Value="#8b949e"/>
                                    <Setter Property="FontWeight" Value="SemiBold"/>
                                    <Setter Property="FontSize" Value="11"/>
                                    <Setter Property="Padding" Value="8,6"/>
                                    <Setter Property="BorderBrush" Value="#2a2a38"/>
                                    <Setter Property="BorderThickness" Value="0,0,1,1"/>
                                </Style>
                            </DataGrid.ColumnHeaderStyle>
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="100"/>
                                <DataGridTextColumn Header="Source (UNC Path)" Binding="{Binding Source}" Width="2*"/>
                                <DataGridTextColumn Header="Destination (Local Path)" Binding="{Binding Destination}" Width="2*"/>
                                <DataGridTextColumn Header="File Types" Binding="{Binding FileTypes}" Width="90"/>
                            </DataGrid.Columns>
                        </DataGrid>

                        <!-- Actions for Selected Row -->
                        <Grid Margin="0,0,0,10">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button x:Name="btnRemoveSelected" Content="Remove Selected Mapping" Style="{StaticResource DangerButton}" Height="26" Margin="0,0,8,0"/>
                                <Button x:Name="btnClearAll" Content="Clear All" Style="{StaticResource SecondaryButton}" Height="26"/>
                            </StackPanel>
                        </Grid>

                        <Separator Background="#2e2e3d" Margin="0,0,0,10"/>

                        <!-- Add New Mapping Form -->
                        <TextBlock Text="Add / Edit Mapping:" Foreground="#d0d0df" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.2*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="2.5*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="2.5*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="1*"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Name" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtMapName" Height="28" Text="Line 1"/>
                            </StackPanel>

                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Source UNC Path" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtMapSource" Height="28" Text="\\10.91.13.204\qw\Test1"/>
                            </StackPanel>

                            <StackPanel Grid.Column="4">
                                <TextBlock Text="Destination Local Path" Style="{StaticResource FieldLabel}"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="txtMapDest" Grid.Column="0" Height="28" Text="C:\temp\TEST\data1"/>
                                    <Button x:Name="btnBrowseDest" Grid.Column="1" Content="..." Width="30" Height="28" Style="{StaticResource SecondaryButton}" Margin="4,0,0,0"/>
                                </Grid>
                            </StackPanel>

                            <StackPanel Grid.Column="6">
                                <TextBlock Text="File Types" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtMapTypes" Height="28" Text="*.csv"/>
                            </StackPanel>

                            <StackPanel Grid.Column="8" VerticalAlignment="Bottom">
                                <Button x:Name="btnAddMapping" Content="+ Add Mapping" Style="{StaticResource SuccessButton}" Height="28" Width="105"/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- Card 3: Deployment & Task Scheduler -->
                <Border Style="{StaticResource CardBorder}">
                    <StackPanel>
                        <TextBlock Text="3. SCRIPT DEPLOYMENT AND TASK SCHEDULER SETTINGS" Style="{StaticResource SectionHeader}"/>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1.2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Deployment Path -->
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Target Script Folder (Location to save .ps1)" Style="{StaticResource FieldLabel}"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="txtDeployFolder" Grid.Column="0" Height="28" Text="C:\Scripts"/>
                                    <Button x:Name="btnBrowseDeploy" Grid.Column="1" Content="..." Width="30" Height="28" Style="{StaticResource SecondaryButton}" Margin="4,0,0,0"/>
                                </Grid>
                            </StackPanel>

                            <!-- Script File Name -->
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Script File Name" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtScriptFileName" Height="28" Text="copy-script.ps1"/>
                            </StackPanel>

                            <!-- Task Name -->
                            <StackPanel Grid.Column="4">
                                <TextBlock Text="Scheduled Task Name" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtTaskName" Height="28" Text="Copy Script v3"/>
                            </StackPanel>

                            <!-- Repeat Minutes -->
                            <StackPanel Grid.Column="6">
                                <TextBlock Text="Interval (Minutes)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtRepeatMinutes" Height="28" Text="1"/>
                            </StackPanel>
                        </Grid>

                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1.2*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Log Folder -->
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Log Directory" Style="{StaticResource FieldLabel}"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="txtLogFolder" Grid.Column="0" Height="28" Text="C:\Scripts\Logs"/>
                                    <Button x:Name="btnBrowseLog" Grid.Column="1" Content="..." Width="30" Height="28" Style="{StaticResource SecondaryButton}" Margin="4,0,0,0"/>
                                </Grid>
                            </StackPanel>

                            <!-- Run As User -->
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Run As Account (Task Scheduler)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtRunAsUser" Height="28" Text="SYSTEM"/>
                            </StackPanel>

                            <!-- Max Log Size MB -->
                            <StackPanel Grid.Column="4">
                                <TextBlock Text="Log Rotation Max Size (MB)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtMaxLogMB" Height="28" Text="10"/>
                            </StackPanel>

                            <!-- Retention Days -->
                            <StackPanel Grid.Column="6">
                                <TextBlock Text="Retention (Days)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtRetentionDays" Height="28" Text="30"/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                </Border>
            </StackPanel>
        </ScrollViewer>

        <!-- Action Buttons -->
        <Grid Grid.Row="2" Margin="0,4,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0" Orientation="Horizontal">
                <Button x:Name="btnSaveScriptOnly" Content="Save Script Only" Style="{StaticResource SecondaryButton}" Height="34" Margin="0,0,8,0"/>
                <Button x:Name="btnRunNow" Content="Run Sync Now" Style="{StaticResource SecondaryButton}" Height="34"/>
            </StackPanel>

            <StackPanel Grid.Column="2" Orientation="Horizontal">
                <Button x:Name="btnDeployAndCreateTask" Content="Generate Script and Install Scheduled Task" Style="{StaticResource PrimaryButton}" Height="34" FontSize="12" Padding="18,6"/>
            </StackPanel>
        </Grid>

        <!-- Console Log Output -->
        <Border Grid.Row="3" Background="#0e0e12" BorderBrush="#2a2a36" BorderThickness="1" CornerRadius="6" Padding="6">
            <TextBox x:Name="txtConsole"
                     IsReadOnly="True"
                     TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"
                     Background="Transparent"
                     Foreground="#3fb950"
                     FontFamily="Consolas, Lucida Console, Courier New"
                     FontSize="11"
                     BorderThickness="0"
                     Padding="4"/>
        </Border>
    </Grid>
</Window>
"@

# ====================================================================
# LOAD XAML & BIND CONTROLS
# ====================================================================

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Auto-bind named controls
$namedElements = @(
    "btnLoadConfig", "txtUsername", "chkShowPassword", "txtPassword", "txtPasswordPlain",
    "btnTestSmb", "lblMappingCount", "dgMappings", "btnRemoveSelected", "btnClearAll",
    "txtMapName", "txtMapSource", "txtMapDest", "btnBrowseDest", "txtMapTypes",
    "btnAddMapping", "txtDeployFolder", "btnBrowseDeploy", "txtScriptFileName",
    "txtTaskName", "txtRepeatMinutes", "txtLogFolder", "btnBrowseLog",
    "txtRunAsUser", "txtMaxLogMB", "txtRetentionDays", "btnSaveScriptOnly",
    "btnRunNow", "btnDeployAndCreateTask", "txtConsole"
)

foreach ($name in $namedElements)
{
    Set-Variable -Name $name -Value ($window.FindName($name))
}

# Mapping ObservableCollection for WPF DataGrid Binding
$script:MappingsCollection = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$dgMappings.ItemsSource = $script:MappingsCollection

# ====================================================================
# LOGGING HELPER
# ====================================================================

function Write-ConsoleLog
{
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $time = Get-Date -Format "HH:mm:ss"
    $formatted = "[$time] [$Level] $Message"

    $window.Dispatcher.Invoke([Action]{
        $txtConsole.AppendText("$formatted`r`n")
        $txtConsole.ScrollToEnd()
    })
}

# ====================================================================
# PASSWORD VISIBILITY TOGGLE
# ====================================================================

$chkShowPassword.Add_Checked({
    $txtPasswordPlain.Text = $txtPassword.Password
    $txtPassword.Visibility = [System.Windows.Visibility]::Collapsed
    $txtPasswordPlain.Visibility = [System.Windows.Visibility]::Visible
})

$chkShowPassword.Add_Unchecked({
    $txtPassword.Password = $txtPasswordPlain.Text
    $txtPasswordPlain.Visibility = [System.Windows.Visibility]::Collapsed
    $txtPassword.Visibility = [System.Windows.Visibility]::Visible
})

function Get-CurrentPassword
{
    if ($chkShowPassword.IsChecked)
    {
        return $txtPasswordPlain.Text
    }
    return $txtPassword.Password
}

function Set-CurrentPassword([string]$pwd)
{
    $txtPassword.Password = $pwd
    $txtPasswordPlain.Text = $pwd
}

# ====================================================================
# FOLDER BROWSING HELPERS
# ====================================================================

function Show-FolderBrowser([string]$initialPath)
{
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = "Select Folder"
    $dialog.ShowNewFolderButton = $true
    if ($initialPath -and (Test-Path -LiteralPath $initialPath -ErrorAction SilentlyContinue))
    {
        $dialog.SelectedPath = $initialPath
    }
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        return $dialog.SelectedPath
    }
    return $null
}

$btnBrowseDest.Add_Click({
    $selected = Show-FolderBrowser $txtMapDest.Text
    if ($selected) { $txtMapDest.Text = $selected }
})

$btnBrowseDeploy.Add_Click({
    $selected = Show-FolderBrowser $txtDeployFolder.Text
    if ($selected) {
        $txtDeployFolder.Text = $selected
        $txtLogFolder.Text = [System.IO.Path]::Combine($selected, "Logs")
    }
})

$btnBrowseLog.Add_Click({
    $selected = Show-FolderBrowser $txtLogFolder.Text
    if ($selected) { $txtLogFolder.Text = $selected }
})

# ====================================================================
# MAPPING MANAGEMENT (ADD / REMOVE / UPDATE)
# ====================================================================

function Update-MappingCount
{
    $lblMappingCount.Text = "$($script:MappingsCollection.Count) Mapping(s) Configured"
}

$btnAddMapping.Add_Click({
    $name = $txtMapName.Text.Trim()
    $src  = $txtMapSource.Text.Trim()
    $dst  = $txtMapDest.Text.Trim()
    $types = $txtMapTypes.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($src) -or [string]::IsNullOrWhiteSpace($dst))
    {
        Write-ConsoleLog "Both Source UNC Path and Destination Path are required to add a mapping." "WARN"
        [System.Windows.MessageBox]::Show("Please enter both Source UNC Path and Destination Local Path.", "Missing Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    if ([string]::IsNullOrWhiteSpace($name))
    {
        $name = "Line $($script:MappingsCollection.Count + 1)"
    }

    if ([string]::IsNullOrWhiteSpace($types))
    {
        $types = "*.*"
    }

    # Check if a mapping with same Name or Source already exists to update
    $existing = $script:MappingsCollection | Where-Object { $_.Name -eq $name -or $_.Source -eq $src }
    if ($existing)
    {
        $script:MappingsCollection.Remove($existing)
    }

    $newObj = [PSCustomObject]@{
        Name        = $name
        Source      = $src
        Destination = $dst
        FileTypes   = $types
        Enabled     = $true
    }

    $script:MappingsCollection.Add($newObj)
    Update-MappingCount
    Write-ConsoleLog "Added mapping: [$name] $src -> $dst ($types)" "SUCCESS"

    # Pre-populate next mapping name
    $nextNum = $script:MappingsCollection.Count + 1
    $txtMapName.Text = "Line $nextNum"
})

$btnRemoveSelected.Add_Click({
    $selected = $dgMappings.SelectedItem
    if ($selected)
    {
        $script:MappingsCollection.Remove($selected)
        Update-MappingCount
        Write-ConsoleLog "Removed mapping: $($selected.Name)" "INFO"
    }
    else
    {
        Write-ConsoleLog "No mapping row selected to remove." "WARN"
    }
})

$btnClearAll.Add_Click({
    if ($script:MappingsCollection.Count -gt 0)
    {
        $script:MappingsCollection.Clear()
        Update-MappingCount
        Write-ConsoleLog "Cleared all mappings." "INFO"
    }
})

# ====================================================================
# TEST SMB CONNECTION
# ====================================================================

$btnTestSmb.Add_Click({
    $username = $txtUsername.Text.Trim()
    $password = Get-CurrentPassword

    if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password))
    {
        Write-ConsoleLog "Please provide both SMB Username and Password to test connection." "WARN"
        return
    }

    # Collect distinct root shares from mappings or Source box
    $sharesToTest = @()
    foreach ($m in $script:MappingsCollection)
    {
        if ($m.Source -and $m.Source.StartsWith("\\"))
        {
            $parts = $m.Source.TrimStart('\').Split('\')
            if ($parts.Length -ge 2)
            {
                $root = "\\$($parts[0])\$($parts[1])"
                if ($sharesToTest -notcontains $root) { $sharesToTest += $root }
            }
        }
    }

    # If no mappings in table yet, test the one in the input box
    if ($sharesToTest.Count -eq 0 -and $txtMapSource.Text.StartsWith("\\"))
    {
        $parts = $txtMapSource.Text.TrimStart('\').Split('\')
        if ($parts.Length -ge 2)
        {
            $sharesToTest += "\\$($parts[0])\$($parts[1])"
        }
    }

    if ($sharesToTest.Count -eq 0)
    {
        Write-ConsoleLog "No UNC shares (e.g. \\10.91.13.204\share) found to test. Please add a mapping first." "WARN"
        return
    }

    Write-ConsoleLog "Starting SMB connectivity test with user '$username'..." "INFO"

    foreach ($share in $sharesToTest)
    {
        Write-ConsoleLog "Testing authentication to: $share" "INFO"

        cmd.exe /c "net use `"$share`" /delete /y" *> $null
        $netOut = cmd.exe /c "net use `"$share`" /user:$username $password /persistent:no" 2>&1

        Start-Sleep -Seconds 1

        if (Test-Path -LiteralPath $share -ErrorAction SilentlyContinue)
        {
            Write-ConsoleLog "SUCCESS: Connected to share $share!" "SUCCESS"
        }
        else
        {
            Write-ConsoleLog "FAILED: Unable to access share $share." "ERROR"
            if ($netOut) { Write-ConsoleLog "  net use error: $netOut" "ERROR" }
        }
    }
})

# ====================================================================
# SCRIPT GENERATION ENGINE
# ====================================================================

function Generate-RobocopyScriptContent
{
    $username     = $txtUsername.Text.Trim()
    $password     = Get-CurrentPassword
    $logFolder    = $txtLogFolder.Text.Trim()
    $maxLogMB     = [int]($txtMaxLogMB.Text.Trim())
    $retention    = [int]($txtRetentionDays.Text.Trim())
    $pollingSec   = [int]($txtRepeatMinutes.Text.Trim()) * 60

    # Build Mappings Code
    $mappingsBuilder = [System.Text.StringBuilder]::new()
    $mappingsBuilder.AppendLine('$FolderMappings = @(') | Out-Null

    $mappingCount = $script:MappingsCollection.Count
    for ($i = 0; $i -lt $mappingCount; $i++)
    {
        $m = $script:MappingsCollection[$i]
        $tList = ($m.FileTypes -split '[,; ]' | Where-Object { $_ -and $_.Trim() } | ForEach-Object { "`"$_`"" }) -join ', '
        if (-not $tList) { $tList = '"*.*"' }

        $mappingsBuilder.AppendLine('    @{') | Out-Null
        $mappingsBuilder.AppendLine("        Name        = `"$($m.Name)`"") | Out-Null
        $mappingsBuilder.AppendLine("        Source      = `"$($m.Source)`"") | Out-Null
        $mappingsBuilder.AppendLine("        Destination = `"$($m.Destination)`"") | Out-Null
        $mappingsBuilder.AppendLine("        FileTypes   = @($tList)") | Out-Null
        $mappingsBuilder.AppendLine('        Enabled     = $true') | Out-Null
        if ($i -lt ($mappingCount - 1)) {
            $mappingsBuilder.AppendLine('    },') | Out-Null
        } else {
            $mappingsBuilder.AppendLine('    }') | Out-Null
        }
    }
    $mappingsBuilder.AppendLine(')') | Out-Null
    $mappingsCode = $mappingsBuilder.ToString()

    $template = @'
<#
====================================================================================================
AVGOL COPY MASTER - AUTO-GENERATED FILE REPLICATION
====================================================================================================
Generated On: __GENERATED_TIMESTAMP__
Configured Mappings: __MAPPING_COUNT__
Log Directory: __LOG_FOLDER__
====================================================================================================
#>

# ====================================================================
# SOURCE SERVER AUTHENTICATION
# ====================================================================

$SourceUsername      = "__SOURCE_USERNAME__"
$SourcePassword      = "__SOURCE_PASSWORD__"

# ====================================================================
# FOLDER MAPPINGS (SOURCE UNC -> LOCAL DESTINATION)
# ====================================================================

__FOLDER_MAPPINGS__

# ====================================================================
# DEFAULT SETTINGS
# ====================================================================

$FileTypes           = @("*.*")
$PollingIntervalSec  = __POLLING_SEC__
$RetryAttempts       = 5
$RetryWaitSeconds    = 15

# ====================================================================
# LOG SETTINGS
# ====================================================================

$LogFolder           = "__LOG_FOLDER__"
$MaxLogSizeMB        = __MAX_LOG_MB__
$MaxArchivedLogs     = 20
$LogRetentionDays    = __RETENTION_DAYS__

# ====================================================================
# CREATE REQUIRED LOG DIRECTORY
# ====================================================================

try
{
    New-Item -ItemType Directory -Path $LogFolder -Force -ErrorAction SilentlyContinue | Out-Null
}
catch {}

$CurrentLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Current.log")

try
{
    if (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue)
    {
        if (!(Test-Path -LiteralPath $CurrentLog))
        {
            New-Item -ItemType File -Path $CurrentLog -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
catch {}

# ====================================================================
# LOGGING
# ====================================================================

function Write-Log
{
    param([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FormattedMessage = "$Timestamp - $Message"

    Write-Host $FormattedMessage

    try
    {
        if ($CurrentLog -and (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue))
        {
            Add-Content -Path $CurrentLog -Value $FormattedMessage -ErrorAction SilentlyContinue
            Rotate-Logs
        }
    }
    catch {}
}

# ====================================================================
# LOG ROTATION
# ====================================================================

function Rotate-SingleLog
{
    param([string]$LogFilePath, [string]$ArchivePrefix)

    try
    {
        if ([string]::IsNullOrWhiteSpace($LogFilePath) -or !(Test-Path -LiteralPath $LogFilePath -ErrorAction SilentlyContinue))
        {
            return
        }

        $LogFile = Get-Item -LiteralPath $LogFilePath -ErrorAction Stop
        $SizeMB = [Math]::Round(($LogFile.Length / 1MB), 2)

        if ($SizeMB -lt $MaxLogSizeMB)
        {
            return
        }

        $ArchiveName = "$($ArchivePrefix)" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log"
        $ArchiveFile = [System.IO.Path]::Combine($LogFolder, $ArchiveName)

        Move-Item -Path $LogFilePath -Destination $ArchiveFile -Force
        New-Item -ItemType File -Path $LogFilePath -Force | Out-Null

        Write-Host "Log Rotated: $ArchiveName"

        $Archives = Get-ChildItem -Path $LogFolder -Filter "$($ArchivePrefix)*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if ($Archives.Count -gt $MaxArchivedLogs)
        {
            $Archives | Select-Object -Skip $MaxArchivedLogs | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Host "Log Rotation Error ($LogFilePath): $_"
    }
}

function Rotate-Logs
{
    Rotate-SingleLog -LogFilePath $CurrentLog -ArchivePrefix "Robocopy_"
    $DetailedLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Detail.log")
    Rotate-SingleLog -LogFilePath $DetailedLog -ArchivePrefix "Robocopy_Detail_"
}

function Cleanup-OldLogs
{
    try
    {
        if (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue)
        {
            Get-ChildItem -Path $LogFolder -Filter "*.log" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Log "Log Cleanup Error: $_"
    }
}

# ====================================================================
# CONNECT TO SOURCE SHARE
# ====================================================================

function Connect-SourceShare
{
    param([Parameter(Mandatory = $true)][string]$SharePath)

    try
    {
        $UNCPath = $SharePath.Trim().TrimEnd('\', '/')
        if ($UNCPath.StartsWith("\\"))
        {
            $parts = $UNCPath.TrimStart('\').Split('\')
            if ($parts.Length -ge 2)
            {
                $UNCPath = "\\$($parts[0])\$($parts[1])"
            }
        }

        Write-Log "Connecting to $UNCPath"
        cmd.exe /c "net use `"$UNCPath`" /delete /y" *> $null
        cmd.exe /c "net use `"$UNCPath`" /user:`"$SourceUsername`" `"$SourcePassword`" /persistent:no" *> $null
        Start-Sleep -Seconds 2

        if (Test-Path -LiteralPath $UNCPath)
        {
            Write-Log "Connection successful to $UNCPath"
            return $true
        }

        Write-Log "Connection failed to $UNCPath"
        return $false
    }
    catch
    {
        Write-Log "Connection Error for $UNCPath : $_"
        return $false
    }
}

# ====================================================================
# RUN ROBOCOPY FOR A SINGLE MAPPING
# ====================================================================

function Start-RobocopyCopy
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    try
    {
        $SourcePath = $Mapping.Source.Trim().TrimEnd('\', '/')
        $DestPath   = $Mapping.Destination.Trim().TrimEnd('\', '/')

        if (!(Test-Path -LiteralPath $DestPath))
        {
            Write-Log "[$($Mapping.Name)] Creating destination directory: $DestPath"
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        if (!(Test-Path -LiteralPath $SourcePath))
        {
            Write-Log "[$($Mapping.Name)] WARNING: Source folder not found or inaccessible: $SourcePath"
            return $false
        }

        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }
        $DetailedLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Detail.log")

        Write-Log "[$($Mapping.Name)] Starting Robocopy Sync"
        Write-Log "[$($Mapping.Name)] Source: $SourcePath"
        Write-Log "[$($Mapping.Name)] Dest  : $DestPath"

        $Arguments = @(
            "`"$SourcePath`"",
            "`"$DestPath`""
        )

        foreach ($ft in $activeTypes)
        {
            if ($ft -and $ft.Trim())
            {
                $ft.Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
                    $Arguments += $_
                }
            }
        }

        $Arguments += @(
            "/E",
            "/Z",
            "/FFT",
            "/XO",
            "/R:$RetryAttempts",
            "/W:$RetryWaitSeconds",
            "/NP",
            "/TEE",
            "/LOG+:`"$DetailedLog`""
        )

        $Process = Start-Process -FilePath "robocopy.exe" -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
        $ExitCode = $Process.ExitCode

        $resultMsg = switch ($ExitCode)
        {
            0 { "No changes detected." }
            1 { "Files copied successfully." }
            2 { "Extra files/directories exist at destination." }
            3 { "Files copied and extra destination files detected." }
            4 { "Mismatched files detected." }
            5 { "Files copied with mismatches detected." }
            6 { "Extras and mismatches detected." }
            7 { "Files copied, extras and mismatches detected." }
            Default { "Robocopy warning/error. Exit Code: $ExitCode" }
        }

        if ($ExitCode -le 7)
        {
            Write-Log "[$($Mapping.Name)] Robocopy Result: $resultMsg (Exit Code: $ExitCode)"
            return $true
        }
        else
        {
            Write-Log "[$($Mapping.Name)] Robocopy Failed: $resultMsg (Exit Code: $ExitCode)"
            return $false
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Robocopy Exception: $_"
        return $false
    }
}

# ====================================================================
# RUN REPLICATION CYCLE
# ====================================================================

function Invoke-Replication
{
    $rootShares = @()
    foreach ($m in $FolderMappings)
    {
        if ($m.Enabled -and $m.Source -and $m.Source.StartsWith("\\"))
        {
            $parts = $m.Source.TrimStart('\').Split('\')
            if ($parts.Length -ge 2)
            {
                $root = "\\$($parts[0])\$($parts[1])"
                if ($rootShares -notcontains $root) { $rootShares += $root }
            }
        }
    }

    if ($rootShares.Count -eq 0)
    {
        Write-Log "ERROR: No remote SMB shares could be detected from `$FolderMappings."
        return
    }

    $connectionFailures = 0
    foreach ($share in $rootShares)
    {
        if (-not (Connect-SourceShare -SharePath $share))
        {
            $connectionFailures++
        }
    }

    if ($connectionFailures -eq $rootShares.Count)
    {
        Write-Log "All source shares are unreachable. Skipping copy cycle."
        return
    }

    $successCount = 0
    $failureCount = 0
    $skippedCount = 0

    foreach ($mapping in $FolderMappings)
    {
        if (-not $mapping.Enabled)
        {
            Write-Log "[$($mapping.Name)] Skipped (Disabled in configuration)"
            $skippedCount++
            continue
        }

        $psobj = [PSCustomObject]$mapping
        $success = Start-RobocopyCopy -Mapping $psobj
        if ($success) { $successCount++ } else { $failureCount++ }
    }

    Write-Log "Replication Cycle Finished: $successCount succeeded, $failureCount failed, $skippedCount skipped."
}

# ====================================================================
# MAIN EXECUTION
# ====================================================================

try
{
    Cleanup-OldLogs
    Invoke-Replication
}
catch
{
    Write-Log "Main Execution Error: $_"
}
'@

    $rendered = $template
    $rendered = $rendered.Replace("__GENERATED_TIMESTAMP__", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    $rendered = $rendered.Replace("__MAPPING_COUNT__", "$($script:MappingsCollection.Count)")
    $rendered = $rendered.Replace("__SOURCE_USERNAME__", $username)
    $rendered = $rendered.Replace("__SOURCE_PASSWORD__", $password)
    $rendered = $rendered.Replace("__FOLDER_MAPPINGS__", $mappingsCode)
    $rendered = $rendered.Replace("__LOG_FOLDER__", $logFolder)
    $rendered = $rendered.Replace("__MAX_LOG_MB__", "$maxLogMB")
    $rendered = $rendered.Replace("__RETENTION_DAYS__", "$retention")
    $rendered = $rendered.Replace("__POLLING_SEC__", "$pollingSec")

    return $rendered
}

# ====================================================================
# SAVE SCRIPT ACTION
# ====================================================================

function Save-ReplicationScript
{
    if ($script:MappingsCollection.Count -eq 0)
    {
        Write-ConsoleLog "No folder mappings defined. Please add at least one mapping before generating." "WARN"
        [System.Windows.MessageBox]::Show("Please configure at least one folder mapping.", "No Mappings", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return $null
    }

    $deployFolder = $txtDeployFolder.Text.Trim()
    $fileName     = $txtScriptFileName.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($deployFolder) -or [string]::IsNullOrWhiteSpace($fileName))
    {
        Write-ConsoleLog "Target deployment folder and script file name cannot be empty." "WARN"
        return $null
    }

    try
    {
        if (!(Test-Path -LiteralPath $deployFolder))
        {
            Write-ConsoleLog "Creating target directory: $deployFolder" "INFO"
            New-Item -ItemType Directory -Path $deployFolder -Force | Out-Null
        }

        $targetPath = [System.IO.Path]::Combine($deployFolder, $fileName)
        $content = Generate-RobocopyScriptContent

        # Validate PowerShell syntax before saving
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors -and $parseErrors.Count -gt 0)
        {
            $errDetail = ($parseErrors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }) -join "`n"
            Write-ConsoleLog "SYNTAX ERROR in generated script:`n$errDetail" "ERROR"
            [System.Windows.MessageBox]::Show("Generated script contains syntax errors:`n`n$errDetail", "Script Syntax Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return $null
        }

        [System.IO.File]::WriteAllText($targetPath, $content, [System.Text.Encoding]::UTF8)
        Write-ConsoleLog "SUCCESS: Generated script saved to: $targetPath" "SUCCESS"

        # Also ensure Log Folder exists
        $logFolder = $txtLogFolder.Text.Trim()
        if ($logFolder -and !(Test-Path -LiteralPath $logFolder))
        {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }

        return $targetPath
    }
    catch
    {
        Write-ConsoleLog "ERROR saving script: $_" "ERROR"
        [System.Windows.MessageBox]::Show("Failed to save script: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }
}

$btnSaveScriptOnly.Add_Click({
    $path = Save-ReplicationScript
    if ($path)
    {
        [System.Windows.MessageBox]::Show("Script successfully generated and saved to:`n$path", "Script Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# ====================================================================
# DEPLOY SCRIPT & INSTALL SCHEDULED TASK
# ====================================================================

$btnDeployAndCreateTask.Add_Click({
    $targetScript = Save-ReplicationScript
    if (-not $targetScript) { return }

    $taskName      = $txtTaskName.Text.Trim()
    $repeatMinutes = [int]($txtRepeatMinutes.Text.Trim())
    $runAsUser     = $txtRunAsUser.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($taskName))
    {
        Write-ConsoleLog "Scheduled Task Name cannot be empty." "WARN"
        return
    }

    if ($repeatMinutes -lt 1) { $repeatMinutes = 1 }

    Write-ConsoleLog "Registering Windows Scheduled Task '$taskName'..." "INFO"

    # Delete existing task if present
    cmd.exe /c "schtasks /Delete /TN `"$taskName`" /F" *> $null

    # Create new task
    $createCmd = "schtasks /Create /TN `"$taskName`" /SC MINUTE /MO $repeatMinutes /TR `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \`"$targetScript\`"`" /RU `"$runAsUser`" /RL HIGHEST /F"
    $createResult = cmd.exe /c $createCmd 2>&1

    if ($LASTEXITCODE -eq 0)
    {
        Write-ConsoleLog "SUCCESS: Windows Scheduled Task '$taskName' created successfully!" "SUCCESS"
        Write-ConsoleLog "  - Script Location : $targetScript" "SUCCESS"
        Write-ConsoleLog "  - Execution Schedule: Every $repeatMinutes minute(s)" "SUCCESS"
        Write-ConsoleLog "  - Run As User       : $runAsUser (Highest Privileges)" "SUCCESS"

        [System.Windows.MessageBox]::Show(
            "Replication Setup Complete!`n`nScript Location:`n$targetScript`n`nScheduled Task:`n'$taskName' scheduled every $repeatMinutes minute(s).",
            "Task Installed Successfully",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
    else
    {
        Write-ConsoleLog "ERROR: Failed to create Scheduled Task." "ERROR"
        Write-ConsoleLog "Details: $createResult" "ERROR"
        Write-ConsoleLog "Please ensure you run this application as Administrator!" "WARN"

        [System.Windows.MessageBox]::Show(
            "Failed to create Scheduled Task:`n$createResult`n`nPlease ensure this tool is run with Administrator privileges.",
            "Task Creation Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
})

# ====================================================================
# RUN REPLICATION NOW (TEST RUN)
# ====================================================================

$btnRunNow.Add_Click({
    $targetScript = [System.IO.Path]::Combine($txtDeployFolder.Text.Trim(), $txtScriptFileName.Text.Trim())

    # If file does not exist yet, generate it first
    if (!(Test-Path -LiteralPath $targetScript))
    {
        $targetScript = Save-ReplicationScript
        if (-not $targetScript) { return }
    }

    Write-ConsoleLog "Executing replication script immediately: $targetScript" "INFO"

    $p = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$targetScript`"" `
        -Wait -NoNewWindow -PassThru

    Write-ConsoleLog "Replication process completed with exit code: $($p.ExitCode)" "SUCCESS"
    Write-ConsoleLog "Check $($txtLogFolder.Text)\Robocopy_Current.log for detailed execution summary." "INFO"
})

# ====================================================================
# LOAD CONFIGURATION FROM LOCAL SCRIPT
# ====================================================================

function Load-LocalScriptConfig
{
    $localScript = [System.IO.Path]::Combine($PSScriptRoot, "copy-script-v3.ps1")
    if (-not $PSScriptRoot)
    {
        $localScript = (Resolve-Path ".\copy-script-v3.ps1" -ErrorAction SilentlyContinue).Path
    }

    if (-not (Test-Path -LiteralPath $localScript -ErrorAction SilentlyContinue))
    {
        Write-ConsoleLog "Local template script not found. Starting with default settings." "INFO"
        return
    }

    try
    {
        Write-ConsoleLog "Reading existing configuration from: $localScript" "INFO"
        $raw = Get-Content -Raw -LiteralPath $localScript

        if ($raw -match '\$SourceUsername\s*=\s*"([^"]+)"')
        {
            $txtUsername.Text = $matches[1]
        }

        if ($raw -match '\$SourcePassword\s*=\s*"([^"]+)"')
        {
            Set-CurrentPassword $matches[1]
        }

        if ($raw -match '\$LogFolder\s*=\s*"([^"]+)"')
        {
            $txtLogFolder.Text = $matches[1]
        }

        # Parse Folder Mappings block in an isolated runspace
        if ($raw -match '(?ms)(# ====================================================================\r?\n# SOURCE SERVER AUTHENTICATION.+?# ====================================================================\r?\n# END CONFIGURATION)')
        {
            $cfg = $matches[1]
            $state = [powershell]::Create()
            $state.AddScript($cfg).Invoke() | Out-Null
            $vars = $state.Runspace.SessionStateProxy.PSVariable
            $mappings = $vars.GetValue("FolderMappings")
            $globalFileTypes = $vars.GetValue("FileTypes")

            if ($mappings)
            {
                $script:MappingsCollection.Clear()
                foreach ($m in $mappings)
                {
                    $tStr = if ($m.FileTypes) { ($m.FileTypes -join ', ') } elseif ($globalFileTypes) { ($globalFileTypes -join ', ') } else { "*.*" }
                    $script:MappingsCollection.Add([PSCustomObject]@{
                        Name        = $m.Name
                        Source      = $m.Source
                        Destination = $m.Destination
                        FileTypes   = $tStr
                        Enabled     = $true
                    })
                }
                Update-MappingCount
                Write-ConsoleLog "Successfully loaded $($script:MappingsCollection.Count) mapping(s) from local script!" "SUCCESS"
            }
        }
    }
    catch
    {
        Write-ConsoleLog "Note: Could not parse local script: $_" "WARN"
    }
}

$btnLoadConfig.Add_Click({
    Load-LocalScriptConfig
})

# ====================================================================
# STARTUP INITIALIZATION
# ====================================================================

$window.Add_Loaded({
    Write-ConsoleLog "Avgol Copy Master initialized." "SUCCESS"
    Write-ConsoleLog "Ready. Configure your SMB source and local destinations below." "INFO"

    # Preload from local copy-script-v3.ps1 if present
    Load-LocalScriptConfig
})

# Display Window
$window.ShowDialog() | Out-Null

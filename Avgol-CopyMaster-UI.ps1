<#
====================================================================================================
AVGOL COPY MASTER - REPLICATION CONFIGURATOR & TASK INSTALLER (GUI)
====================================================================================================
Description:
A modern, standalone Windows WPF GUI to configure multi-folder, multi-protocol replication
(SMB, SFTP, SCP, FTPS, FTP, WebDAV), test network credentials and ports, generate SSH keys &
TLS/mTLS certificates, inspect remote server firewall/authorized_keys instructions, generate
production-ready scripts, and create Windows Scheduled Tasks in a single click.

100% Air-Gap Compatible: Zero internet or third-party dependencies required.
====================================================================================================
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Include Security & Cryptography Engine
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$secModule = [System.IO.Path]::Combine($scriptDir, "Avgol-SecurityProtocols.ps1")
if (Test-Path -LiteralPath $secModule)
{
    . $secModule
}

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Avgol Copy Master - Multi-Protocol Replication Suite"
    Width="1020" Height="860"
    MinWidth="880" MinHeight="700"
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

        <!-- Purple Security Button -->
        <Style x:Key="SecurityButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#6e40c9"/>
            <Setter Property="Foreground" Value="#ffffff"/>
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
                <TextBlock Text="Industrial Multi-Folder Replication Suite (SMB, SFTP, SCP, FTPS, FTP, WebDAV)" FontSize="11" Foreground="#8b949e" Margin="0,2,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button x:Name="btnShowServerGuide" Content="Remote Server Setup &amp; Firewall Guide" Style="{StaticResource SecurityButton}" Height="30" Margin="0,0,8,0"/>
                <Button x:Name="btnLoadConfig" Content="Reload From Local Script" Style="{StaticResource SecondaryButton}" Height="30" VerticalAlignment="Center"/>
            </StackPanel>
        </Grid>

        <!-- Scrollable Cards -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,8,0">
            <StackPanel>
                <!-- Card 1: Protocol & Authentication -->
                <Border Style="{StaticResource CardBorder}">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Protocol Selection Bar -->
                        <Grid Grid.Row="0" Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="1. PROTOCOL &amp; ENDPOINT AUTHENTICATION" Style="{StaticResource SectionHeader}" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="2" Orientation="Horizontal">
                                <TextBlock Text="Protocol:" Foreground="#8b949e" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <ComboBox x:Name="cmbProtocol" Width="140" Height="28" Background="#121216" Foreground="#ffffff">
                                    <ComboBoxItem Content="SMB" IsSelected="True"/>
                                    <ComboBoxItem Content="SFTP"/>
                                    <ComboBoxItem Content="SCP"/>
                                    <ComboBoxItem Content="FTPS"/>
                                    <ComboBoxItem Content="FTP"/>
                                    <ComboBoxItem Content="WebDAV"/>
                                </ComboBox>
                                <TextBlock Text="Port:" Foreground="#8b949e" FontSize="11" VerticalAlignment="Center" Margin="12,0,6,0"/>
                                <TextBox x:Name="txtPort" Width="55" Height="28" Text="445" HorizontalContentAlignment="Center"/>
                            </StackPanel>
                        </Grid>

                        <!-- Host, Username, Password, Connection Test -->
                        <Grid Grid.Row="1" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="1.5*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="1.2*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Remote Host / Server IP -->
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Remote Host / Server IP" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtHost" Height="30" Text="10.91.13.204"/>
                            </StackPanel>

                            <!-- Username -->
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Username (e.g. 10.91.13.204\admin)" Style="{StaticResource FieldLabel}"/>
                                <TextBox x:Name="txtUsername" Height="30" Text="10.91.13.204\admin"/>
                            </StackPanel>

                            <!-- Password -->
                            <StackPanel Grid.Column="4">
                                <Grid>
                                    <TextBlock Text="Password / Secret" Style="{StaticResource FieldLabel}"/>
                                    <CheckBox x:Name="chkShowPassword" Content="Show" HorizontalAlignment="Right" Foreground="#8b949e" FontSize="10"/>
                                </Grid>
                                <Grid>
                                    <PasswordBox x:Name="txtPassword" Height="30"/>
                                    <TextBox x:Name="txtPasswordPlain" Height="30" Visibility="Collapsed"/>
                                </Grid>
                            </StackPanel>

                            <!-- Test Connection Button -->
                            <StackPanel Grid.Column="6">
                                <TextBlock Text="Connectivity Check" Style="{StaticResource FieldLabel}"/>
                                <Button x:Name="btnTestSmb" Content="Test Connection" Style="{StaticResource SecondaryButton}" Height="30"/>
                            </StackPanel>
                        </Grid>

                        <!-- Dynamic Security Panel: SSH Keys / TLS Certificates -->
                        <StackPanel Grid.Row="2" x:Name="pnlSecurityOptions" Margin="0,4,0,0">
                            <!-- SSH / SFTP / SCP Key Panel -->
                            <Border x:Name="pnlSshKeyBox" Background="#161b22" BorderBrush="#30363d" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,4,0,0" Visibility="Collapsed">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="8"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="SSH Private Key:" Foreground="#7ee787" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <TextBox x:Name="txtSshKeyPath" Grid.Column="1" Height="28" Text="" VerticalAlignment="Center"/>
                                    <Button x:Name="btnBrowseSshKey" Grid.Column="2" Content="Browse..." Width="70" Height="28" Style="{StaticResource SecondaryButton}" Margin="6,0,0,0"/>
                                    <Button x:Name="btnManageSshKeys" Grid.Column="4" Content="SSH Key Wizard (Paste / Generate)" Style="{StaticResource SecurityButton}" Height="28"/>
                                </Grid>
                            </Border>

                            <!-- TLS / FTPS / WebDAV Certificate Panel -->
                            <Border x:Name="pnlTlsCertBox" Background="#1f1a28" BorderBrush="#4f3869" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,4,0,0" Visibility="Collapsed">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="8"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="TLS / PFX Cert:" Foreground="#d2a8ff" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <TextBox x:Name="txtTlsPfxPath" Grid.Column="1" Height="28" Text="" VerticalAlignment="Center"/>
                                    <Button x:Name="btnBrowseTlsPfx" Grid.Column="2" Content="Browse..." Width="70" Height="28" Style="{StaticResource SecondaryButton}" Margin="6,0,0,0"/>
                                    <Button x:Name="btnManageTlsCert" Grid.Column="4" Content="TLS Cert Wizard (Paste / Generate)" Style="{StaticResource SecurityButton}" Height="28"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- Card 2: Folder Mappings -->
                <Border Style="{StaticResource CardBorder}">
                    <StackPanel>
                        <Grid Margin="0,0,0,8">
                            <TextBlock Text="2. FOLDER MAPPINGS (REMOTE SOURCE -> LOCAL DESTINATION)" Style="{StaticResource SectionHeader}" VerticalAlignment="Center"/>
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
                                <DataGridTextColumn Header="Source (UNC / Remote Path)" Binding="{Binding Source}" Width="2*"/>
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
                                <TextBlock Text="Source Path (UNC or Remote)" Style="{StaticResource FieldLabel}"/>
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

                <!-- Card 3: Data Lifecycle & Archive Policies -->
                <Border Style="{StaticResource CardBorder}">
                    <StackPanel>
                        <TextBlock Text="3. DATA LIFECYCLE &amp; ARCHIVE POLICIES" Style="{StaticResource SectionHeader}"/>

                        <!-- Source File Deletion Policy -->
                        <Border Background="#1a1612" BorderBrush="#78350f" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,0,0,10">
                            <StackPanel>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <CheckBox x:Name="chkEnableSourceDelete" Content="Delete data at Source(s) after replication" Foreground="#f59e0b" FontWeight="SemiBold" FontSize="12" VerticalAlignment="Center"/>
                                    <Border Grid.Column="1" HorizontalAlignment="Right" Background="#451a03" CornerRadius="3" Padding="6,2">
                                        <TextBlock Text="WARNING: DELETES REMOTE SOURCE DATA" Foreground="#f87171" FontSize="10" FontWeight="Bold"/>
                                    </Border>
                                </Grid>

                                <TextBlock Text="When enabled, files at remote source locations older than the specified days (from last modified date) are safely deleted after destination copy verification."
                                           Foreground="#9ca3af" FontSize="11" Margin="22,4,0,8" TextWrapping="Wrap"/>

                                <Grid x:Name="pnlSourceDeleteOptions" Margin="22,0,0,0" Visibility="Collapsed">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="10"/>
                                        <ColumnDefinition Width="100"/>
                                        <ColumnDefinition Width="10"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Delete source files older than:" Foreground="#e5e7eb" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBox x:Name="txtSourceDeleteDays" Grid.Column="2" Height="28" Text="30" HorizontalContentAlignment="Center"/>
                                    <TextBlock Grid.Column="4" Text="Days (from last modified date of the source file)" Foreground="#8b949e" FontSize="11" VerticalAlignment="Center"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Destination Monthly Archive & Purge Policy -->
                        <Border Background="#121824" BorderBrush="#1e3a5f" BorderThickness="1" CornerRadius="4" Padding="12">
                            <StackPanel>
                                <CheckBox x:Name="chkEnableDestArchive" Content="Auto-Archive at Destination (Monthly YYYY-MM structure)" Foreground="#60a5fa" FontWeight="SemiBold" FontSize="12"/>
                                <TextBlock Text="Automatically organizes files generated/modified in previous months into year-month folders (e.g. '2026-09') under each destination folder."
                                           Foreground="#9ca3af" FontSize="11" Margin="22,4,0,8" TextWrapping="Wrap"/>

                                <StackPanel x:Name="pnlDestArchiveOptions" Margin="22,0,0,0" Visibility="Collapsed">
                                    <Separator Background="#212f45" Margin="0,4,0,10"/>

                                    <Grid Margin="0,0,0,6">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <CheckBox x:Name="chkEnableDestDelete" Content="Delete old monthly archive folders at Destination" Foreground="#fbbf24" FontWeight="SemiBold" FontSize="11" VerticalAlignment="Center"/>
                                        <Border Grid.Column="1" HorizontalAlignment="Right" Background="#381e09" CornerRadius="3" Padding="6,2">
                                            <TextBlock Text="AUTO-PURGE DESTINATION ARCHIVES" Foreground="#f59e0b" FontSize="10" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>

                                    <TextBlock Text="Permanently deletes historical monthly archive folders and their data once they exceed the configured age in months."
                                               Foreground="#9ca3af" FontSize="11" Margin="22,0,0,8" TextWrapping="Wrap"/>

                                    <Grid x:Name="pnlDestDeleteOptions" Margin="22,0,0,0" Visibility="Collapsed">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="100"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Delete archive folders older than:" Foreground="#e5e7eb" FontSize="11" VerticalAlignment="Center"/>
                                        <TextBox x:Name="txtDestDeleteMonths" Grid.Column="2" Height="28" Text="6" HorizontalContentAlignment="Center"/>
                                        <TextBlock Grid.Column="4" Text="Months (from current month)" Foreground="#8b949e" FontSize="11" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Border>

                <!-- Card 4: Deployment & Task Scheduler -->
                <Border Style="{StaticResource CardBorder}">
                    <StackPanel>
                        <TextBlock Text="4. SCRIPT DEPLOYMENT AND TASK SCHEDULER SETTINGS" Style="{StaticResource SectionHeader}"/>

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
    "btnLoadConfig", "btnShowServerGuide", "cmbProtocol", "txtPort", "txtHost",
    "txtUsername", "chkShowPassword", "txtPassword", "txtPasswordPlain",
    "btnTestSmb", "pnlSecurityOptions", "pnlSshKeyBox", "txtSshKeyPath",
    "btnBrowseSshKey", "btnManageSshKeys", "pnlTlsCertBox", "txtTlsPfxPath",
    "btnBrowseTlsPfx", "btnManageTlsCert", "lblMappingCount", "dgMappings",
    "btnRemoveSelected", "btnClearAll", "txtMapName", "txtMapSource", "txtMapDest",
    "btnBrowseDest", "txtMapTypes", "btnAddMapping", "chkEnableSourceDelete",
    "pnlSourceDeleteOptions", "txtSourceDeleteDays", "chkEnableDestArchive",
    "pnlDestArchiveOptions", "chkEnableDestDelete", "pnlDestDeleteOptions",
    "txtDestDeleteMonths", "txtDeployFolder", "btnBrowseDeploy", "txtScriptFileName",
    "txtTaskName", "txtRepeatMinutes", "txtLogFolder", "btnBrowseLog",
    "txtRunAsUser", "txtMaxLogMB", "txtRetentionDays", "btnSaveScriptOnly",
    "btnRunNow", "btnDeployAndCreateTask", "txtConsole"
)

foreach ($name in $namedElements)
{
    Set-Variable -Name $name -Value ($window.FindName($name))
}

# State variables for SSH & TLS
$script:CurrentSshPublicKey  = ""
$script:CurrentSshPrivateKey = ""
$script:CurrentTlsCertThumb  = ""
$script:CurrentTlsCommonName = "avgol-copymaster.local"
$script:CurrentTlsPfxPass    = "AvgolSecurePassword123!"

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
# PROTOCOL SELECTOR LOGIC
# ====================================================================

function Update-ProtocolUI
{
    $proto = $cmbProtocol.Text
    if (-not $proto)
    {
        $proto = ($cmbProtocol.SelectedItem.Content).ToString()
    }

    $meta = $script:SupportedProtocols[$proto]
    if ($meta)
    {
        $txtPort.Text = "$($meta.DefaultPort)"
        Write-ConsoleLog "Protocol selected: $proto (Default Port: $($meta.DefaultPort))" "INFO"

        if ($meta.RequiresSSH)
        {
            $pnlSshKeyBox.Visibility = [System.Windows.Visibility]::Visible
            $pnlTlsCertBox.Visibility = [System.Windows.Visibility]::Collapsed
        }
        elseif ($meta.RequiresTLS)
        {
            $pnlSshKeyBox.Visibility = [System.Windows.Visibility]::Collapsed
            $pnlTlsCertBox.Visibility = [System.Windows.Visibility]::Visible
        }
        else
        {
            $pnlSshKeyBox.Visibility = [System.Windows.Visibility]::Collapsed
            $pnlTlsCertBox.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

$cmbProtocol.Add_SelectionChanged({
    Update-ProtocolUI
})

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

function Show-FileBrowser([string]$filter = "All files (*.*)|*.*")
{
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = $filter
    $dialog.CheckFileExists = $true
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        return $dialog.FileName
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

$btnBrowseSshKey.Add_Click({
    $selected = Show-FileBrowser "SSH Private Keys (*;*.pem;*.id_*)|*|All files (*.*)|*.*"
    if ($selected)
    {
        $txtSshKeyPath.Text = $selected
        if (Test-Path -LiteralPath "$selected.pub")
        {
            $script:CurrentSshPublicKey = (Get-Content -Raw -LiteralPath "$selected.pub").Trim()
        }
        Write-ConsoleLog "Loaded SSH Private Key file: $selected" "SUCCESS"
    }
})

$btnBrowseTlsPfx.Add_Click({
    $selected = Show-FileBrowser "PKCS#12 Certificates (*.pfx;*.p12)|*.pfx;*.p12|PEM Certificates (*.cer;*.crt)|*.cer;*.crt|All files (*.*)|*.*"
    if ($selected)
    {
        $txtTlsPfxPath.Text = $selected
        Write-ConsoleLog "Loaded TLS Certificate: $selected" "SUCCESS"
    }
})

# ====================================================================
# SSH KEY WIZARD MODAL (PASTE OR GENERATE)
# ====================================================================

function Show-SshKeyWizardDialog
{
    $dialog = [System.Windows.Window]::new()
    $dialog.Title = "SSH Key Wizard - Avgol Copy Master"
    $dialog.Width = 680
    $dialog.Height = 560
    $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#18181f")
    $dialog.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f0f0f5")
    $dialog.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")

    $root = [System.Windows.Controls.Grid]::new()
    $root.Margin = [System.Windows.Thickness]::new(14)
    
    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r3 = [System.Windows.Controls.RowDefinition]::new(); $r3.Height = [System.Windows.GridLength]::Auto
    $root.RowDefinitions.Add($r0); $root.RowDefinitions.Add($r1); $root.RowDefinitions.Add($r2); $root.RowDefinitions.Add($r3)

    # Header
    $hdr = [System.Windows.Controls.StackPanel]::new()
    $t1 = [System.Windows.Controls.TextBlock]::new(); $t1.Text = "SSH Key Pair Management"; $t1.FontSize = 16; $t1.FontWeight = [System.Windows.FontWeights]::Bold; $t1.Foreground = [System.Windows.Media.Brushes]::White
    $t2 = [System.Windows.Controls.TextBlock]::new(); $t2.Text = "Paste your existing SSH keypair below, or click 'Generate New Key Pair' to auto-generate an ed25519 / RSA key."
    $t2.FontSize = 11; $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8b949e"); $t2.Margin = [System.Windows.Thickness]::new(0,2,0,10)
    $hdr.Children.Add($t1); $hdr.Children.Add($t2)
    [System.Windows.Controls.Grid]::SetRow($hdr, 0)
    $root.Children.Add($hdr)

    # Box 1: Private Key
    $b1 = [System.Windows.Controls.GroupBox]::new()
    $b1.Header = "SSH Private Key (Client Machine)"
    $b1.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#58a6ff")
    $b1.Margin = [System.Windows.Thickness]::new(0,0,0,8)
    $txtPriv = [System.Windows.Controls.TextBox]::new()
    $txtPriv.AcceptsReturn = $true; $txtPriv.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $txtPriv.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121216")
    $txtPriv.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffffff")
    $txtPriv.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas"); $txtPriv.FontSize = 10
    $b1.Content = $txtPriv
    [System.Windows.Controls.Grid]::SetRow($b1, 1)
    $root.Children.Add($b1)

    # Box 2: Public Key
    $b2 = [System.Windows.Controls.GroupBox]::new()
    $b2.Header = "SSH Public Key (Deploy to Remote ~/.ssh/authorized_keys)"
    $b2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7ee787")
    $b2.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $txtPub = [System.Windows.Controls.TextBox]::new()
    $txtPub.AcceptsReturn = $true; $txtPub.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $txtPub.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121216")
    $txtPub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffffff")
    $txtPub.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas"); $txtPub.FontSize = 10
    $b2.Content = $txtPub
    [System.Windows.Controls.Grid]::SetRow($b2, 2)
    $root.Children.Add($b2)

    # Load existing if available
    if ($txtSshKeyPath.Text -and (Test-Path -LiteralPath $txtSshKeyPath.Text))
    {
        $txtPriv.Text = Get-Content -Raw -LiteralPath $txtSshKeyPath.Text
    }
    if ($script:CurrentSshPublicKey)
    {
        $txtPub.Text = $script:CurrentSshPublicKey
    }

    # Footer Buttons
    $btnBar = [System.Windows.Controls.Grid]::new()
    $c0 = [System.Windows.Controls.ColumnDefinition]::new(); $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = [System.Windows.Controls.ColumnDefinition]::new(); $c2.Width = [System.Windows.GridLength]::Auto
    $btnBar.ColumnDefinitions.Add($c0); $btnBar.ColumnDefinitions.Add($c1); $btnBar.ColumnDefinitions.Add($c2)

    $btnGen = [System.Windows.Controls.Button]::new(); $btnGen.Content = "+ Generate New ed25519 Key Pair"; $btnGen.Height = 32; $btnGen.Padding = [System.Windows.Thickness]::new(12,4,12,4)
    $btnGen.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#238636"); $btnGen.Foreground = [System.Windows.Media.Brushes]::White; $btnGen.FontWeight = [System.Windows.FontWeights]::SemiBold
    [System.Windows.Controls.Grid]::SetColumn($btnGen, 0); $btnBar.Children.Add($btnGen)

    $rightPnl = [System.Windows.Controls.StackPanel]::new(); $rightPnl.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnCopyPub = [System.Windows.Controls.Button]::new(); $btnCopyPub.Content = "Copy Public Key"; $btnCopyPub.Height = 32; $btnCopyPub.Padding = [System.Windows.Thickness]::new(10,4,10,4); $btnCopyPub.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    $btnCopyPub.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2d2d3a"); $btnCopyPub.Foreground = [System.Windows.Media.Brushes]::White
    $btnSave = [System.Windows.Controls.Button]::new(); $btnSave.Content = "Save & Apply Keys"; $btnSave.Height = 32; $btnSave.Padding = [System.Windows.Thickness]::new(14,4,14,4)
    $btnSave.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0969da"); $btnSave.Foreground = [System.Windows.Media.Brushes]::White; $btnSave.FontWeight = [System.Windows.FontWeights]::SemiBold
    $rightPnl.Children.Add($btnCopyPub); $rightPnl.Children.Add($btnSave)
    [System.Windows.Controls.Grid]::SetColumn($rightPnl, 2); $btnBar.Children.Add($rightPnl)

    [System.Windows.Controls.Grid]::SetRow($btnBar, 3)
    $root.Children.Add($btnBar)

    # Event handlers
    $btnGen.Add_Click({
        $res = New-AvgolSSHKeyPair -KeyType "ed25519"
        if ($res.Success)
        {
            $txtPriv.Text = $res.PrivateKeyContent
            $txtPub.Text = $res.PublicKeyContent
            $script:generatedKeyPath = $res.PrivateKeyPath
            [System.Windows.MessageBox]::Show("New ed25519 SSH Key Pair generated successfully!`n`nPrivate Key Saved to:`n$($res.PrivateKeyPath)`n`nPublic Key Saved to:`n$($res.PublicKeyPath)", "SSH Keys Generated", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        else
        {
            [System.Windows.MessageBox]::Show("Failed to generate SSH key: $($res.Error)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })

    $btnCopyPub.Add_Click({
        if ($txtPub.Text)
        {
            [System.Windows.Clipboard]::SetText($txtPub.Text.Trim())
            [System.Windows.MessageBox]::Show("Public Key copied to clipboard! Paste it into the remote server's ~/.ssh/authorized_keys file.", "Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    })

    $btnSave.Add_Click({
        $privText = $txtPriv.Text.Trim()
        $pubText  = $txtPub.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($privText))
        {
            [System.Windows.MessageBox]::Show("Private key cannot be empty. Please paste or generate one.", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        # Save private key to user .ssh if not already a file
        $targetDir = "$env:USERPROFILE\.ssh"
        if (!(Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

        $keyFile = [System.IO.Path]::Combine($targetDir, "id_avgol_custom")
        [System.IO.File]::WriteAllText($keyFile, $privText, [System.Text.Encoding]::ASCII)
        if ($pubText)
        {
            [System.IO.File]::WriteAllText("$keyFile.pub", $pubText, [System.Text.Encoding]::ASCII)
            $script:CurrentSshPublicKey = $pubText
        }

        $txtSshKeyPath.Text = $keyFile
        Write-ConsoleLog "Applied SSH key: $keyFile" "SUCCESS"
        $dialog.DialogResult = $true
        $dialog.Close()
    })

    $dialog.Content = $root
    $dialog.ShowDialog() | Out-Null
}

$btnManageSshKeys.Add_Click({
    Show-SshKeyWizardDialog
})

# ====================================================================
# TLS / X.509 CERTIFICATE WIZARD MODAL
# ====================================================================

function Show-TlsCertWizardDialog
{
    $dialog = [System.Windows.Window]::new()
    $dialog.Title = "TLS / mTLS Certificate Wizard - Avgol Copy Master"
    $dialog.Width = 720
    $dialog.Height = 580
    $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#18181f")
    $dialog.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f0f0f5")
    $dialog.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")

    $root = [System.Windows.Controls.Grid]::new()
    $root.Margin = [System.Windows.Thickness]::new(14)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r3 = [System.Windows.Controls.RowDefinition]::new(); $r3.Height = [System.Windows.GridLength]::Auto
    $root.RowDefinitions.Add($r0); $root.RowDefinitions.Add($r1); $root.RowDefinitions.Add($r2); $root.RowDefinitions.Add($r3)

    # Header
    $hdr = [System.Windows.Controls.StackPanel]::new()
    $t1 = [System.Windows.Controls.TextBlock]::new(); $t1.Text = "TLS / mTLS Certificate & Security Setup"; $t1.FontSize = 16; $t1.FontWeight = [System.Windows.FontWeights]::Bold; $t1.Foreground = [System.Windows.Media.Brushes]::White
    $t2 = [System.Windows.Controls.TextBlock]::new(); $t2.Text = "Generate self-signed X.509 certificates (4096-bit RSA) or configure existing PFX credentials for FTPS / WebDAV."
    $t2.FontSize = 11; $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8b949e"); $t2.Margin = [System.Windows.Thickness]::new(0,2,0,10)
    $hdr.Children.Add($t1); $hdr.Children.Add($t2)
    [System.Windows.Controls.Grid]::SetRow($hdr, 0)
    $root.Children.Add($hdr)

    # Inputs: Common Name & PFX Password
    $gInputs = [System.Windows.Controls.Grid]::new(); $gInputs.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $ci0 = [System.Windows.Controls.ColumnDefinition]::new(); $ci0.Width = [System.Windows.GridLength]::new(2, [System.Windows.GridUnitType]::Star)
    $ci1 = [System.Windows.Controls.ColumnDefinition]::new(); $ci1.Width = [System.Windows.GridLength]::new(10, [System.Windows.GridUnitType]::Pixel)
    $ci2 = [System.Windows.Controls.ColumnDefinition]::new(); $ci2.Width = [System.Windows.GridLength]::new(1.5, [System.Windows.GridUnitType]::Star)
    $gInputs.ColumnDefinitions.Add($ci0); $gInputs.ColumnDefinitions.Add($ci1); $gInputs.ColumnDefinitions.Add($ci2)

    $spCn = [System.Windows.Controls.StackPanel]::new()
    $lblCn = [System.Windows.Controls.TextBlock]::new(); $lblCn.Text = "Certificate Subject / Common Name (e.g. 10.91.13.204 or server.local)"; $lblCn.FontSize = 11; $lblCn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#b0b0c0")
    $txtCn = [System.Windows.Controls.TextBox]::new(); $txtCn.Height = 28; $txtCn.Text = if ($txtHost.Text) { $txtHost.Text } else { "avgol-copymaster.local" }
    $spCn.Children.Add($lblCn); $spCn.Children.Add($txtCn)
    [System.Windows.Controls.Grid]::SetColumn($spCn, 0); $gInputs.Children.Add($spCn)

    $spPw = [System.Windows.Controls.StackPanel]::new()
    $lblPw = [System.Windows.Controls.TextBlock]::new(); $lblPw.Text = "PFX Export Password"; $lblPw.FontSize = 11; $lblPw.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#b0b0c0")
    $txtPfxPw = [System.Windows.Controls.TextBox]::new(); $txtPfxPw.Height = 28; $txtPfxPw.Text = "AvgolSecurePassword123!"
    $spPw.Children.Add($lblPw); $spPw.Children.Add($txtPfxPw)
    [System.Windows.Controls.Grid]::SetColumn($spPw, 2); $gInputs.Children.Add($spPw)

    [System.Windows.Controls.Grid]::SetRow($gInputs, 1)
    $root.Children.Add($gInputs)

    # Details Box
    $bCert = [System.Windows.Controls.GroupBox]::new()
    $bCert.Header = "Generated Certificate Details & PEM Preview"
    $bCert.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#d2a8ff")
    $bCert.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $txtCertPreview = [System.Windows.Controls.TextBox]::new()
    $txtCertPreview.AcceptsReturn = $true; $txtCertPreview.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $txtCertPreview.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121216")
    $txtCertPreview.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffffff")
    $txtCertPreview.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas"); $txtCertPreview.FontSize = 10
    $bCert.Content = $txtCertPreview
    [System.Windows.Controls.Grid]::SetRow($bCert, 2)
    $root.Children.Add($bCert)

    # Footer Buttons
    $btnBar = [System.Windows.Controls.Grid]::new()
    $c0 = [System.Windows.Controls.ColumnDefinition]::new(); $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = [System.Windows.Controls.ColumnDefinition]::new(); $c2.Width = [System.Windows.GridLength]::Auto
    $btnBar.ColumnDefinitions.Add($c0); $btnBar.ColumnDefinitions.Add($c1); $btnBar.ColumnDefinitions.Add($c2)

    $btnGen = [System.Windows.Controls.Button]::new(); $btnGen.Content = "+ Generate Self-Signed Certificate"; $btnGen.Height = 32; $btnGen.Padding = [System.Windows.Thickness]::new(12,4,12,4)
    $btnGen.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#238636"); $btnGen.Foreground = [System.Windows.Media.Brushes]::White; $btnGen.FontWeight = [System.Windows.FontWeights]::SemiBold
    [System.Windows.Controls.Grid]::SetColumn($btnGen, 0); $btnBar.Children.Add($btnGen)

    $rightPnl = [System.Windows.Controls.StackPanel]::new(); $rightPnl.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnCopyPem = [System.Windows.Controls.Button]::new(); $btnCopyPem.Content = "Copy Public PEM"; $btnCopyPem.Height = 32; $btnCopyPem.Padding = [System.Windows.Thickness]::new(10,4,10,4); $btnCopyPem.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    $btnCopyPem.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2d2d3a"); $btnCopyPem.Foreground = [System.Windows.Media.Brushes]::White
    $btnApply = [System.Windows.Controls.Button]::new(); $btnApply.Content = "Apply Certificate"; $btnApply.Height = 32; $btnApply.Padding = [System.Windows.Thickness]::new(14,4,14,4)
    $btnApply.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0969da"); $btnApply.Foreground = [System.Windows.Media.Brushes]::White; $btnApply.FontWeight = [System.Windows.FontWeights]::SemiBold
    $rightPnl.Children.Add($btnCopyPem); $rightPnl.Children.Add($btnApply)
    [System.Windows.Controls.Grid]::SetColumn($rightPnl, 2); $btnBar.Children.Add($rightPnl)

    [System.Windows.Controls.Grid]::SetRow($btnBar, 3)
    $root.Children.Add($btnBar)

    # Generated state
    $script:generatedPfxPath = ""

    $btnGen.Add_Click({
        $cn = $txtCn.Text.Trim()
        $pw = $txtPfxPw.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($cn)) { $cn = "avgol-copymaster.local" }

        $res = New-AvgolSelfSignedTlsCert -CommonName $cn -PfxPassword $pw
        if ($res.Success)
        {
            $script:generatedPfxPath     = $res.PfxPath
            $script:CurrentTlsCertThumb  = $res.Thumbprint
            $script:CurrentTlsCommonName = $res.CommonName
            $script:CurrentTlsPfxPass    = $pw

            $txtCertPreview.Text = "Thumbprint : $($res.Thumbprint)`r`nValid Until: $($res.NotAfter)`r`nPFX Path   : $($res.PfxPath)`r`nCER Path   : $($res.CerPath)`r`nPEM Path   : $($res.PemCertPath)`r`n`r`n--- PUBLIC CERTIFICATE PEM ---`r`n$($res.PublicCertPem)"
            [System.Windows.MessageBox]::Show("Self-Signed TLS Certificate generated successfully!`n`nThumbprint: $($res.Thumbprint)`nPFX File: $($res.PfxPath)`nPassword: $pw", "Certificate Created", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
        else
        {
            [System.Windows.MessageBox]::Show("Certificate Generation Failed: $($res.Error)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })

    $btnCopyPem.Add_Click({
        if ($txtCertPreview.Text)
        {
            [System.Windows.Clipboard]::SetText($txtCertPreview.Text)
            [System.Windows.MessageBox]::Show("Certificate details and PEM copied to clipboard!", "Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    })

    $btnApply.Add_Click({
        if ($script:generatedPfxPath)
        {
            $txtTlsPfxPath.Text = $script:generatedPfxPath
            Write-ConsoleLog "Applied TLS PFX Certificate: $($script:generatedPfxPath) (Thumbprint: $($script:CurrentTlsCertThumb))" "SUCCESS"
        }
        $dialog.DialogResult = $true
        $dialog.Close()
    })

    $dialog.Content = $root
    $dialog.ShowDialog() | Out-Null
}

$btnManageTlsCert.Add_Click({
    Show-TlsCertWizardDialog
})

# ====================================================================
# REMOTE SERVER SETUP & FIREWALL GUIDE MODAL
# ====================================================================

function Show-RemoteServerGuideDialog
{
    $proto = $cmbProtocol.Text
    if (-not $proto) { $proto = ($cmbProtocol.SelectedItem.Content).ToString() }
    $port = 0
    [int]::TryParse($txtPort.Text.Trim(), [ref]$port) | Out-Null
    $hostName = $txtHost.Text.Trim()
    $user = $txtUsername.Text.Trim()

    $guide = Get-RemoteServerSetupGuide `
        -Protocol $proto `
        -RemoteHost $hostName `
        -Port $port `
        -RemoteUser $user `
        -PublicKeyContent $script:CurrentSshPublicKey `
        -CertThumbprint $script:CurrentTlsCertThumb `
        -CertCommonName $script:CurrentTlsCommonName

    $dialog = [System.Windows.Window]::new()
    $dialog.Title = "Remote Server Security & Firewall Configuration Guide ($proto Port $port)"
    $dialog.Width = 820
    $dialog.Height = 620
    $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#18181f")
    $dialog.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f0f0f5")
    $dialog.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")

    $root = [System.Windows.Controls.Grid]::new()
    $root.Margin = [System.Windows.Thickness]::new(14)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::Auto
    $root.RowDefinitions.Add($r0); $root.RowDefinitions.Add($r1); $root.RowDefinitions.Add($r2)

    # Header
    $hdr = [System.Windows.Controls.StackPanel]::new()
    $t1 = [System.Windows.Controls.TextBlock]::new(); $t1.Text = "Remote Server Deployment & Port Verification"; $t1.FontSize = 16; $t1.FontWeight = [System.Windows.FontWeights]::Bold; $t1.Foreground = [System.Windows.Media.Brushes]::White
    $t2 = [System.Windows.Controls.TextBlock]::new(); $t2.Text = "Follow these instructions on the remote server ($hostName) to open ports, configure firewalls, and install keys/certs."
    $t2.FontSize = 11; $t2.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8b949e"); $t2.Margin = [System.Windows.Thickness]::new(0,2,0,10)
    $hdr.Children.Add($t1); $hdr.Children.Add($t2)
    [System.Windows.Controls.Grid]::SetRow($hdr, 0)
    $root.Children.Add($hdr)

    # Guide Box
    $txtGuide = [System.Windows.Controls.TextBox]::new()
    $txtGuide.IsReadOnly = $true
    $txtGuide.AcceptsReturn = $true
    $txtGuide.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $txtGuide.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $txtGuide.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121216")
    $txtGuide.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ade80")
    $txtGuide.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas")
    $txtGuide.FontSize = 11
    $txtGuide.Padding = [System.Windows.Thickness]::new(8)
    $txtGuide.Text = $guide
    [System.Windows.Controls.Grid]::SetRow($txtGuide, 1)
    $root.Children.Add($txtGuide)

    # Buttons
    $pnlBtn = [System.Windows.Controls.StackPanel]::new(); $pnlBtn.Orientation = [System.Windows.Controls.Orientation]::Horizontal; $pnlBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $pnlBtn.Margin = [System.Windows.Thickness]::new(0,10,0,0)

    $btnCopyGuide = [System.Windows.Controls.Button]::new(); $btnCopyGuide.Content = "Copy Guide to Clipboard"; $btnCopyGuide.Height = 32; $btnCopyGuide.Padding = [System.Windows.Thickness]::new(14,4,14,4); $btnCopyGuide.Margin = [System.Windows.Thickness]::new(0,0,8,0)
    $btnCopyGuide.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2d2d3a"); $btnCopyGuide.Foreground = [System.Windows.Media.Brushes]::White
    $btnClose = [System.Windows.Controls.Button]::new(); $btnClose.Content = "Close"; $btnClose.Height = 32; $btnClose.Padding = [System.Windows.Thickness]::new(18,4,18,4)
    $btnClose.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0969da"); $btnClose.Foreground = [System.Windows.Media.Brushes]::White

    $btnCopyGuide.Add_Click({
        [System.Windows.Clipboard]::SetText($guide)
        [System.Windows.MessageBox]::Show("Guide copied to clipboard!", "Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })

    $btnClose.Add_Click({ $dialog.Close() })

    $pnlBtn.Children.Add($btnCopyGuide); $pnlBtn.Children.Add($btnClose)
    [System.Windows.Controls.Grid]::SetRow($pnlBtn, 2)
    $root.Children.Add($pnlBtn)

    $dialog.Content = $root
    $dialog.ShowDialog() | Out-Null
}

$btnShowServerGuide.Add_Click({
    Show-RemoteServerGuideDialog
})

# ====================================================================
# DATA LIFECYCLE & RETENTION EVENT HANDLERS
# ====================================================================

$script:isLoadingConfig = $false

$chkEnableSourceDelete.Add_Checked({
    if ($script:isLoadingConfig)
    {
        $pnlSourceDeleteOptions.Visibility = [System.Windows.Visibility]::Visible
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "CRITICAL WARNING: REMOTE SOURCE DATA DELETION!`n`n" +
        "You are about to enable automatic deletion of source files after replication.`n`n" +
        "Files at the remote source location(s) that are older than the configured threshold (from their last modified date) will be PERMANENTLY DELETED.`n`n" +
        "Safety Guarantee: A file will ONLY be deleted from the source after it has been verified to exist at the destination with matching size.`n`n" +
        "Are you sure you want to enable Source Data Deletion?",
        "Avgol Copy Master - Confirm Source Data Deletion",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes)
    {
        $pnlSourceDeleteOptions.Visibility = [System.Windows.Visibility]::Visible
        Write-ConsoleLog "WARNING: Source Data Deletion policy has been turned ON." "WARN"
    }
    else
    {
        $chkEnableSourceDelete.IsChecked = $false
        $pnlSourceDeleteOptions.Visibility = [System.Windows.Visibility]::Collapsed
    }
})

$chkEnableSourceDelete.Add_Unchecked({
    $pnlSourceDeleteOptions.Visibility = [System.Windows.Visibility]::Collapsed
    if (-not $script:isLoadingConfig)
    {
        Write-ConsoleLog "Source Data Deletion policy turned OFF." "INFO"
    }
})

$chkEnableDestArchive.Add_Checked({
    $pnlDestArchiveOptions.Visibility = [System.Windows.Visibility]::Visible
    if (-not $script:isLoadingConfig)
    {
        Write-ConsoleLog "Destination Monthly Auto-Archive (YYYY-MM) turned ON." "INFO"
    }
})

$chkEnableDestArchive.Add_Unchecked({
    $pnlDestArchiveOptions.Visibility = [System.Windows.Visibility]::Collapsed
    $chkEnableDestDelete.IsChecked = $false
    $pnlDestDeleteOptions.Visibility = [System.Windows.Visibility]::Collapsed
    if (-not $script:isLoadingConfig)
    {
        Write-ConsoleLog "Destination Monthly Auto-Archive turned OFF." "INFO"
    }
})

$chkEnableDestDelete.Add_Checked({
    if ($script:isLoadingConfig)
    {
        $pnlDestDeleteOptions.Visibility = [System.Windows.Visibility]::Visible
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "WARNING: DESTINATION ARCHIVE PURGE!`n`n" +
        "You are about to enable automatic deletion of historical archive folders at the destination.`n`n" +
        "Old monthly archive folders (e.g. '2025-08') and all files inside them older than the configured month threshold will be PERMANENTLY PURGED.`n`n" +
        "Are you sure you want to enable automatic deletion of old monthly destination archives?",
        "Avgol Copy Master - Confirm Destination Archive Purge",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes)
    {
        $pnlDestDeleteOptions.Visibility = [System.Windows.Visibility]::Visible
        Write-ConsoleLog "WARNING: Destination Archive Purge policy has been turned ON." "WARN"
    }
    else
    {
        $chkEnableDestDelete.IsChecked = $false
        $pnlDestDeleteOptions.Visibility = [System.Windows.Visibility]::Collapsed
    }
})

$chkEnableDestDelete.Add_Unchecked({
    $pnlDestDeleteOptions.Visibility = [System.Windows.Visibility]::Collapsed
    if (-not $script:isLoadingConfig)
    {
        Write-ConsoleLog "Destination Archive Purge policy turned OFF." "INFO"
    }
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
        Write-ConsoleLog "Both Source Path and Destination Path are required to add a mapping." "WARN"
        [System.Windows.MessageBox]::Show("Please enter both Source Path and Destination Local Path.", "Missing Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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
# TEST PROTOCOL & PORT CONNECTION
# ====================================================================

$btnTestSmb.Add_Click({
    $proto = $cmbProtocol.Text
    if (-not $proto) { $proto = ($cmbProtocol.SelectedItem.Content).ToString() }

    $port = 0
    [int]::TryParse($txtPort.Text.Trim(), [ref]$port) | Out-Null
    $hostName = $txtHost.Text.Trim()
    $username = $txtUsername.Text.Trim()
    $password = Get-CurrentPassword
    $keyPath  = $txtSshKeyPath.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($hostName))
    {
        Write-ConsoleLog "Remote Host / IP cannot be empty." "WARN"
        return
    }

    Write-ConsoleLog "Testing $proto connectivity to ${hostName}:${port}..." "INFO"

    $testRes = Test-AvgolProtocolEndpoint `
        -Protocol $proto `
        -HostName $hostName `
        -Port $port `
        -Username $username `
        -Password $password `
        -PrivateKeyPath $keyPath

    if ($testRes.PortOpen -and $testRes.AuthSuccess)
    {
        Write-ConsoleLog "SUCCESS: $($testRes.Message)" "SUCCESS"
        [System.Windows.MessageBox]::Show($testRes.Message, "Connection Successful", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
    elseif ($testRes.PortOpen)
    {
        Write-ConsoleLog "PORT OPEN: $($testRes.Message)" "WARN"
        [System.Windows.MessageBox]::Show($testRes.Message, "Port Open (Auth Pending)", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
    else
    {
        Write-ConsoleLog "FAILED: $($testRes.Message)" "ERROR"
        [System.Windows.MessageBox]::Show($testRes.Message, "Connection Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

# ====================================================================
# SCRIPT GENERATION ENGINE
# ====================================================================

function Generate-RobocopyScriptContent
{
    $proto        = $cmbProtocol.Text
    if (-not $proto) { $proto = ($cmbProtocol.SelectedItem.Content).ToString() }
    $port         = [int]($txtPort.Text.Trim())
    $hostName     = $txtHost.Text.Trim()
    $username     = $txtUsername.Text.Trim()
    $password     = Get-CurrentPassword
    $sshKey       = $txtSshKeyPath.Text.Trim()
    $tlsPfx       = $txtTlsPfxPath.Text.Trim()
    $tlsPass      = $script:CurrentTlsPfxPass
    $tlsThumb     = $script:CurrentTlsCertThumb

    $logFolder    = $txtLogFolder.Text.Trim()
    $maxLogMB     = [int]($txtMaxLogMB.Text.Trim())
    $retention    = [int]($txtRetentionDays.Text.Trim())
    $pollingSec   = [int]($txtRepeatMinutes.Text.Trim()) * 60

    $enableSrcDel   = if ($chkEnableSourceDelete.IsChecked) { '$true' } else { '$false' }
    $srcDelDays     = [int]($txtSourceDeleteDays.Text.Trim())
    if ($srcDelDays -lt 1) { $srcDelDays = 1 }

    $enableDestArch = if ($chkEnableDestArchive.IsChecked) { '$true' } else { '$false' }
    $enableDestDel  = if ($chkEnableDestDelete.IsChecked) { '$true' } else { '$false' }
    $destDelMonths  = [int]($txtDestDeleteMonths.Text.Trim())
    if ($destDelMonths -lt 1) { $destDelMonths = 1 }

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
AVGOL COPY MASTER - AUTO-GENERATED MULTI-PROTOCOL FILE REPLICATION
====================================================================================================
Generated On        : __GENERATED_TIMESTAMP__
Protocol            : __SOURCE_PROTOCOL__ (Port __SOURCE_PORT__)
Remote Host         : __SOURCE_HOST__
Configured Mappings : __MAPPING_COUNT__
Log Directory       : __LOG_FOLDER__
====================================================================================================
#>

# ====================================================================
# PROTOCOL & AUTHENTICATION CONFIGURATION
# ====================================================================

$SourceProtocol      = "__SOURCE_PROTOCOL__"
$SourcePort          = __SOURCE_PORT__
$SourceHost          = "__SOURCE_HOST__"
$SourceUsername      = "__SOURCE_USERNAME__"
$SourcePassword      = "__SOURCE_PASSWORD__"

# SSH / Key-Based Authentication (SFTP & SCP)
$SshPrivateKeyPath   = "__SSH_KEY_PATH__"

# TLS / Certificate Authentication (FTPS & WebDAV)
$TlsCertThumbprint   = "__TLS_CERT_THUMB__"
$TlsPfxPath          = "__TLS_PFX_PATH__"
$TlsPfxPassword      = "__TLS_PFX_PASSWORD__"

# ====================================================================
# FOLDER MAPPINGS (REMOTE SOURCE -> LOCAL DESTINATION)
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
# DATA LIFECYCLE & RETENTION POLICIES
# ====================================================================

# 1. Source Data Deletion (Delete old files from Source)
$EnableSourceDelete         = __ENABLE_SOURCE_DELETE__
$SourceDeleteDays           = __SOURCE_DELETE_DAYS__

# 2. Destination Monthly Auto-Archive (YYYY-MM structure)
$EnableDestMonthlyArchive   = __ENABLE_DEST_ARCHIVE__

# 3. Destination Archive Purge (Delete old YYYY-MM folders)
$EnableDestArchiveDelete    = __ENABLE_DEST_DELETE__
$DestArchiveDeleteMonths    = __DEST_DELETE_MONTHS__

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
# CONNECT TO SOURCE SHARE (SMB)
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
# SFTP / SCP REPLICATION ADAPTER
# ====================================================================

function Invoke-SshFileReplication
{
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Mapping,
        [string]$Mode = "SFTP"
    )

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        $port = if ($SourcePort -gt 0) { $SourcePort } else { 22 }
        $hostName = if ($SourceHost) { $SourceHost } else { "127.0.0.1" }
        $user = if ($SourceUsername) { $SourceUsername } else { $env:USERNAME }
        $remoteSrc = $Mapping.Source.Replace("\", "/")

        $authArg = ""
        if ($SshPrivateKeyPath -and (Test-Path -LiteralPath $SshPrivateKeyPath))
        {
            $authArg = "-i `"$SshPrivateKeyPath`""
        }

        Write-Log "[$($Mapping.Name)] Starting $Mode Transfer from ${user}@${hostName}:${remoteSrc} -> $DestPath"

        if ($Mode -eq "SCP")
        {
            $scpCmd = Get-Command "scp.exe" -ErrorAction SilentlyContinue
            if (-not $scpCmd)
            {
                Write-Log "[$($Mapping.Name)] ERROR: scp.exe not found on system."
                return $false
            }

            $scpArgs = "-P $port -o StrictHostKeyChecking=no -o BatchMode=yes $authArg -r `"${user}@${hostName}:${remoteSrc}/*`" `"$DestPath`""
            $proc = Start-Process -FilePath "scp.exe" -ArgumentList $scpArgs -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -eq 0)
            {
                Write-Log "[$($Mapping.Name)] SCP transfer completed successfully."
                return $true
            }
            else
            {
                Write-Log "[$($Mapping.Name)] SCP transfer failed with exit code: $($proc.ExitCode)"
                return $false
            }
        }
        else
        {
            $sftpCmd = Get-Command "sftp.exe" -ErrorAction SilentlyContinue
            if (-not $sftpCmd)
            {
                Write-Log "[$($Mapping.Name)] ERROR: sftp.exe not found on system."
                return $false
            }

            $batchFile = [System.IO.Path]::GetTempFileName()
            $batchContent = "cd `"$remoteSrc`"`nlcd `"$DestPath`"`nmget *`nbye`n"
            [System.IO.File]::WriteAllText($batchFile, $batchContent, [System.Text.Encoding]::ASCII)

            $sftpArgs = "-P $port -o StrictHostKeyChecking=no -o BatchMode=yes $authArg -b `"$batchFile`" ${user}@${hostName}"
            $proc = Start-Process -FilePath "sftp.exe" -ArgumentList $sftpArgs -Wait -NoNewWindow -PassThru
            Remove-Item -LiteralPath $batchFile -Force -ErrorAction SilentlyContinue

            if ($proc.ExitCode -eq 0)
            {
                Write-Log "[$($Mapping.Name)] SFTP transfer completed successfully."
                return $true
            }
            else
            {
                Write-Log "[$($Mapping.Name)] SFTP transfer exited with code: $($proc.ExitCode)"
                return $false
            }
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] SSH transfer exception: $_"
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
            "/LOG+:`"$DetailedLog`"",
            "/XD",
            "20*"
        )

        # Exclude source files from re-copying if already archived into monthly subfolders
        if ($EnableDestMonthlyArchive)
        {
            $now = Get-Date
            $curMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)
            $srcFiles = Get-ChildItem -LiteralPath $SourcePath -File -ErrorAction SilentlyContinue
            $xfList = @()
            foreach ($sf in $srcFiles)
            {
                if ($sf.LastWriteTime -lt $curMonthStart)
                {
                    $ym = $sf.LastWriteTime.ToString("yyyy-MM")
                    $archPath = [System.IO.Path]::Combine($DestPath, $ym, $sf.Name)
                    if (Test-Path -LiteralPath $archPath)
                    {
                        $xfList += $sf.Name
                    }
                }
            }
            if ($xfList.Count -gt 0)
            {
                $Arguments += "/XF"
                foreach ($xf in $xfList)
                {
                    $Arguments += $xf
                }
            }
        }

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
# UNIFIED REPLICATION DISPATCHER
# ====================================================================

function Start-UnifiedCopy
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if ($SourceProtocol -in @("SFTP", "SCP"))
    {
        return Invoke-SshFileReplication -Mapping $Mapping -Mode $SourceProtocol
    }
    else
    {
        return Start-RobocopyCopy -Mapping $Mapping
    }
}

# ====================================================================
# DESTINATION MONTHLY AUTO-ARCHIVE
# ====================================================================

function Invoke-DestinationMonthlyArchive
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableDestMonthlyArchive)
    {
        return
    }

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            return
        }

        $now = Get-Date
        $currentMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)

        $destFiles = Get-ChildItem -LiteralPath $DestPath -File -ErrorAction SilentlyContinue
        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }

        $archivedCount = 0

        foreach ($df in $destFiles)
        {
            $matchesType = $false
            foreach ($pattern in $activeTypes)
            {
                if ($df.Name -like $pattern) { $matchesType = $true; break }
            }
            if (-not $matchesType) { continue }

            if ($df.LastWriteTime -lt $currentMonthStart)
            {
                $ym = $df.LastWriteTime.ToString("yyyy-MM")
                $targetDir = [System.IO.Path]::Combine($DestPath, $ym)

                if (!(Test-Path -LiteralPath $targetDir))
                {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    Write-Log "[$($Mapping.Name)] Created monthly archive folder: $ym"
                }

                $targetFilePath = [System.IO.Path]::Combine($targetDir, $df.Name)
                Move-Item -LiteralPath $df.FullName -Destination $targetFilePath -Force
                Write-Log "[$($Mapping.Name)] [DEST ARCHIVE] Moved '$($df.Name)' (Modified: $($df.LastWriteTime.ToString('yyyy-MM-dd'))) -> '$ym\'"
                $archivedCount++
            }
        }

        if ($archivedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Monthly Archive: $archivedCount file(s) moved to YYYY-MM archive folders."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Destination Monthly Archive Error: $_"
    }
}

# ====================================================================
# DESTINATION ARCHIVE PURGE (DELETE OLD MONTHLY FOLDERS)
# ====================================================================

function Invoke-DestinationArchivePurge
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableDestArchiveDelete -or $DestArchiveDeleteMonths -lt 1)
    {
        return
    }

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            return
        }

        $now = Get-Date
        $currentMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)
        $cutoffMonth = $currentMonthStart.AddMonths(-$DestArchiveDeleteMonths)

        $monthFolders = Get-ChildItem -LiteralPath $DestPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-(0[1-9]|1[0-2])$' }

        $purgedCount = 0

        foreach ($mf in $monthFolders)
        {
            try
            {
                $folderDate = [DateTime]::ParseExact($mf.Name, "yyyy-MM", [System.Globalization.CultureInfo]::InvariantCulture)
                if ($folderDate -lt $cutoffMonth)
                {
                    Write-Log "[$($Mapping.Name)] [DEST PURGE] Permanently deleting expired archive folder: $($mf.Name) (Cutoff: $($cutoffMonth.ToString('yyyy-MM')))"
                    Remove-Item -LiteralPath $mf.FullName -Recurse -Force -ErrorAction Stop
                    $purgedCount++
                }
            }
            catch
            {
                Write-Log "[$($Mapping.Name)] [DEST PURGE ERROR] Failed removing $($mf.Name): $_"
            }
        }

        if ($purgedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Destination Purge: $purgedCount old monthly archive folder(s) removed."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Destination Archive Purge Error: $_"
    }
}

# ====================================================================
# REMOTE SOURCE CLEANUP (DELETE OLD SOURCE FILES)
# ====================================================================

function Invoke-SourceCleanup
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableSourceDelete -or $SourceDeleteDays -lt 1)
    {
        return
    }

    try
    {
        $SourcePath = $Mapping.Source.Trim().TrimEnd('\', '/')
        $DestPath   = $Mapping.Destination.Trim().TrimEnd('\', '/')

        if (!(Test-Path -LiteralPath $SourcePath))
        {
            return
        }

        $cutoff = (Get-Date).AddDays(-$SourceDeleteDays)
        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }

        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] Checking for source files older than $SourceDeleteDays days (Cutoff: $($cutoff.ToString('yyyy-MM-dd HH:mm')))..."

        $sourceFiles = Get-ChildItem -LiteralPath $SourcePath -File -ErrorAction SilentlyContinue

        $deletedCount = 0
        $skippedCount = 0

        foreach ($sf in $sourceFiles)
        {
            $matchesType = $false
            foreach ($pattern in $activeTypes)
            {
                if ($sf.Name -like $pattern) { $matchesType = $true; break }
            }
            if (-not $matchesType) { continue }

            if ($sf.LastWriteTime -lt $cutoff)
            {
                # Verification: verify file exists at destination (root or monthly archive) with matching size
                $destRootFile = [System.IO.Path]::Combine($DestPath, $sf.Name)
                $ym = $sf.LastWriteTime.ToString("yyyy-MM")
                $destArchFile = [System.IO.Path]::Combine($DestPath, $ym, $sf.Name)

                $verified = $false
                if (Test-Path -LiteralPath $destRootFile)
                {
                    $df = Get-Item -LiteralPath $destRootFile -ErrorAction SilentlyContinue
                    if ($df -and $df.Length -eq $sf.Length) { $verified = $true }
                }
                elseif (Test-Path -LiteralPath $destArchFile)
                {
                    $af = Get-Item -LiteralPath $destArchFile -ErrorAction SilentlyContinue
                    if ($af -and $af.Length -eq $sf.Length) { $verified = $true }
                }

                if ($verified)
                {
                    try
                    {
                        Remove-Item -LiteralPath $sf.FullName -Force -ErrorAction Stop
                        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] Deleted verified source file: $($sf.Name) (Modified: $($sf.LastWriteTime.ToString('yyyy-MM-dd')))"
                        $deletedCount++
                    }
                    catch
                    {
                        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP ERROR] Failed to delete $($sf.Name): $_"
                    }
                }
                else
                {
                    Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] SKIPPED: $($sf.Name) is older than $SourceDeleteDays days but is NOT yet verified at destination."
                    $skippedCount++
                }
            }
        }

        if ($deletedCount -gt 0 -or $skippedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Source Cleanup: $deletedCount deleted, $skippedCount unverified."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Source Cleanup Error: $_"
    }
}

# ====================================================================
# RUN REPLICATION CYCLE
# ====================================================================

function Invoke-Replication
{
    if ($SourceProtocol -eq "SMB")
    {
        $rootShares = @()
        $hasLocalSource = $false
        foreach ($m in $FolderMappings)
        {
            if ($m.Enabled -and $m.Source)
            {
                if ($m.Source.StartsWith("\\"))
                {
                    $parts = $m.Source.TrimStart('\').Split('\')
                    if ($parts.Length -ge 2)
                    {
                        $root = "\\$($parts[0])\$($parts[1])"
                        if ($rootShares -notcontains $root) { $rootShares += $root }
                    }
                }
                else
                {
                    $hasLocalSource = $true
                }
            }
        }

        if ($rootShares.Count -eq 0 -and -not $hasLocalSource)
        {
            Write-Log "ERROR: No remote SMB shares or valid source paths could be detected from `$FolderMappings."
            return
        }

        $connectionFailures = 0
        if ($rootShares.Count -gt 0)
        {
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
        }
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
        $success = Start-UnifiedCopy -Mapping $psobj
        if ($success) { $successCount++ } else { $failureCount++ }

        # Post-Copy Lifecycle Actions:
        if ($success -or (Test-Path -LiteralPath $psobj.Destination))
        {
            # 1. Destination Monthly Auto-Archive (YYYY-MM structure)
            if ($EnableDestMonthlyArchive)
            {
                Invoke-DestinationMonthlyArchive -Mapping $psobj
            }

            # 2. Destination Archive Purge (Delete old YYYY-MM folders)
            if ($EnableDestArchiveDelete)
            {
                Invoke-DestinationArchivePurge -Mapping $psobj
            }

            # 3. Source File Cleanup (Delete verified source files older than X days)
            if ($EnableSourceDelete)
            {
                Invoke-SourceCleanup -Mapping $psobj
            }
        }
    }

    Write-Log "Replication Cycle Finished ($SourceProtocol): $successCount succeeded, $failureCount failed, $skippedCount skipped."
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
    $rendered = $rendered.Replace("__SOURCE_PROTOCOL__", $proto)
    $rendered = $rendered.Replace("__SOURCE_PORT__", "$port")
    $rendered = $rendered.Replace("__SOURCE_HOST__", $hostName)
    $rendered = $rendered.Replace("__SOURCE_USERNAME__", $username)
    $rendered = $rendered.Replace("__SOURCE_PASSWORD__", $password)
    $rendered = $rendered.Replace("__SSH_KEY_PATH__", $sshKey)
    $rendered = $rendered.Replace("__TLS_CERT_THUMB__", $tlsThumb)
    $rendered = $rendered.Replace("__TLS_PFX_PATH__", $tlsPfx)
    $rendered = $rendered.Replace("__TLS_PFX_PASSWORD__", $tlsPass)
    $rendered = $rendered.Replace("__FOLDER_MAPPINGS__", $mappingsCode)
    $rendered = $rendered.Replace("__LOG_FOLDER__", $logFolder)
    $rendered = $rendered.Replace("__MAX_LOG_MB__", "$maxLogMB")
    $rendered = $rendered.Replace("__RETENTION_DAYS__", "$retention")
    $rendered = $rendered.Replace("__POLLING_SEC__", "$pollingSec")
    $rendered = $rendered.Replace("__ENABLE_SOURCE_DELETE__", $enableSrcDel)
    $rendered = $rendered.Replace("__SOURCE_DELETE_DAYS__", "$srcDelDays")
    $rendered = $rendered.Replace("__ENABLE_DEST_ARCHIVE__", $enableDestArch)
    $rendered = $rendered.Replace("__ENABLE_DEST_DELETE__", $enableDestDel)
    $rendered = $rendered.Replace("__DEST_DELETE_MONTHS__", "$destDelMonths")

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
    $candidateNames = @("Avgol-CopyScript.ps1", "copy-script-v3.ps1", "copy-script.ps1")
    $localScript = $null
    $baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    foreach ($cand in $candidateNames)
    {
        $testP = [System.IO.Path]::Combine($baseDir, $cand)
        if (Test-Path -LiteralPath $testP -ErrorAction SilentlyContinue)
        {
            $localScript = $testP
            break
        }
    }

    if (-not $localScript -or -not (Test-Path -LiteralPath $localScript -ErrorAction SilentlyContinue))
    {
        Write-ConsoleLog "Local template script not found. Starting with default settings." "INFO"
        return
    }

    try
    {
        Write-ConsoleLog "Reading existing configuration from: $localScript" "INFO"
        $raw = Get-Content -Raw -LiteralPath $localScript

        if ($raw -match '\$SourceProtocol\s*=\s*"([^"]+)"')
        {
            $loadedProto = $matches[1]
            foreach ($item in $cmbProtocol.Items)
            {
                if ($item.Content -eq $loadedProto)
                {
                    $cmbProtocol.SelectedItem = $item
                    break
                }
            }
        }

        if ($raw -match '\$SourcePort\s*=\s*(\d+)')
        {
            $txtPort.Text = $matches[1]
        }

        if ($raw -match '\$SourceHost\s*=\s*"([^"]+)"')
        {
            $txtHost.Text = $matches[1]
        }

        if ($raw -match '\$SourceUsername\s*=\s*"([^"]+)"')
        {
            $txtUsername.Text = $matches[1]
        }

        if ($raw -match '\$SourcePassword\s*=\s*"([^"]+)"')
        {
            Set-CurrentPassword $matches[1]
        }

        if ($raw -match '\$SshPrivateKeyPath\s*=\s*"([^"]+)"')
        {
            $txtSshKeyPath.Text = $matches[1]
        }

        if ($raw -match '\$TlsPfxPath\s*=\s*"([^"]+)"')
        {
            $txtTlsPfxPath.Text = $matches[1]
        }

        if ($raw -match '\$LogFolder\s*=\s*"([^"]+)"')
        {
            $txtLogFolder.Text = $matches[1]
        }

        # Lifecycle Policies
        if ($raw -match '\$EnableSourceDelete\s*=\s*\$(true|false)')
        {
            $chkEnableSourceDelete.IsChecked = ($matches[1] -eq 'true')
            $pnlSourceDeleteOptions.Visibility = if ($chkEnableSourceDelete.IsChecked) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
        if ($raw -match '\$SourceDeleteDays\s*=\s*(\d+)')
        {
            $txtSourceDeleteDays.Text = $matches[1]
        }
        if ($raw -match '\$EnableDestMonthlyArchive\s*=\s*\$(true|false)')
        {
            $chkEnableDestArchive.IsChecked = ($matches[1] -eq 'true')
            $pnlDestArchiveOptions.Visibility = if ($chkEnableDestArchive.IsChecked) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
        if ($raw -match '\$EnableDestArchiveDelete\s*=\s*\$(true|false)')
        {
            $chkEnableDestDelete.IsChecked = ($matches[1] -eq 'true')
            $pnlDestDeleteOptions.Visibility = if ($chkEnableDestDelete.IsChecked) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
        if ($raw -match '\$DestArchiveDeleteMonths\s*=\s*(\d+)')
        {
            $txtDestDeleteMonths.Text = $matches[1]
        }

        # Parse Folder Mappings block in an isolated runspace
        if ($raw -match '(?ms)(\$FolderMappings\s*=\s*@\(.+?\r?\n\))')
        {
            $cfg = $matches[1]
            $state = [powershell]::Create()
            $state.AddScript($cfg).Invoke() | Out-Null
            $vars = $state.Runspace.SessionStateProxy.PSVariable
            $mappings = $vars.GetValue("FolderMappings")

            if ($mappings)
            {
                $script:MappingsCollection.Clear()
                foreach ($m in $mappings)
                {
                    $tStr = if ($m.FileTypes) { ($m.FileTypes -join ', ') } else { "*.*" }
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
    Write-ConsoleLog "Avgol Copy Master initialized with Multi-Protocol Engine." "SUCCESS"
    Write-ConsoleLog "Supported: SMB (445), SFTP (22), SCP (22), FTPS (990), FTP (21), WebDAV (443)." "INFO"

    # Preload from local script if present
    Load-LocalScriptConfig
    Update-ProtocolUI
})

# Display Window
$window.ShowDialog() | Out-Null

<#
.SYNOPSIS
    Profile component 19 - Tool Integrations And Code Completions
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 19 (TOOL INTEGRATIONS AND CODE COMPLETIONS) for modular dot-sourced loading.
#>

#region 19 - TOOL INTEGRATIONS AND CODE COMPLETIONS
#==============================================================================
<#
.SYNOPSIS
    Third-party tool integrations with enhanced argument completion
.DESCRIPTION
    Provides argument completers and enhanced integrations for development tools,
    package managers, and frameworks.
#>

#------------------------------------------------------------------------------
# Helper function for registering completions
#------------------------------------------------------------------------------

function Register-ToolCompletion {
    <#
    .SYNOPSIS
        Registers argument completion for a tool.
    .PARAMETER Command
        Command name.
    .PARAMETER ScriptBlock
        Completion scriptblock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    if (Get-Command -Name $Command -ErrorAction Ignore) {
        Register-ArgumentCompleter -CommandName $Command -ScriptBlock $ScriptBlock
    }
}

if ((Test-ProfileInteractive) -and $Global:ProfileConfig.Features.UseCompletions) {

#------------------------------------------------------------------------------
# Winget Completions
#------------------------------------------------------------------------------

$WingetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('install', 'show', 'source', 'search', 'list', 'upgrade', 'uninstall', 'hash', 'validate', 'settings', 'features', 'export', 'import', 'pin', 'configure', 'repair')
    $options = @('--version', '--info', '--help', '--wait', '--verbose', '--nowarn', '--disable-interactivity', '--rainbow')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'winget' -ScriptBlock $WingetCompletion

#------------------------------------------------------------------------------
# Chocolatey Completions
#------------------------------------------------------------------------------

$ChocoCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('install', 'upgrade', 'uninstall', 'search', 'list', 'info', 'outdated', 'pin', 'unpin', 'config', 'feature', 'apikey', 'unpackself', 'version', 'download')
    $options = @('--version', '--help', '-v', '--verbose', '--debug', '--accept-license', '-y', '--yes', '--force', '--noop', '--whatif')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'choco' -ScriptBlock $ChocoCompletion

#------------------------------------------------------------------------------
# Scoop Completions
#------------------------------------------------------------------------------

$ScoopCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('install', 'uninstall', 'update', 'upgrade', 'search', 'list', 'show', 'info', 'cleanup', 'bucket', 'cache', 'alias', 'reset', 'hold', 'unhold', 'status', 'cat', 'checkup', 'shim', 'which')
    $options = @('--version', '--help', '-g', '--global')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'scoop' -ScriptBlock $ScoopCompletion

#------------------------------------------------------------------------------
# NPM/Yarn/PNPM Completions
#------------------------------------------------------------------------------

$NpmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('install', 'uninstall', 'update', 'outdated', 'search', 'ls', 'list', 'run', 'start', 'test', 'build', 'publish', 'init', 'config', 'cache', 'audit', 'fix', 'fund', 'info', 'view', 'adduser', 'logout', 'whoami', 'version', 'prune', 'dedupe')
    $options = @('--version', '--help', '-g', '--global', '--save', '--save-dev', '--save-optional', '--save-exact', '--force', '--production', '--json')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'npm' -ScriptBlock $NpmCompletion

$YarnCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('add', 'audit', 'autoclean', 'bin', 'cache', 'check', 'config', 'create', 'dedupe', 'generate-lock-entry', 'global', 'help', 'import', 'info', 'init', 'install', 'licenses', 'link', 'list', 'login', 'logout', 'node', 'outdated', 'owner', 'pack', 'policies', 'publish', 'remove', 'run', 'self-update', 'tag', 'team', 'test', 'upgrade', 'upgrade-interactive', 'version', 'versions', 'why', 'workspace', 'workspaces')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'yarn' -ScriptBlock $YarnCompletion

$PnpmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('add', 'audit', 'bin', 'config', 'exec', 'fetch', 'import', 'info', 'init', 'install', 'link', 'list', 'outdated', 'pack', 'prune', 'publish', 'rebuild', 'remove', 'run', 'search', 'start', 'store', 'test', 'unlink', 'update', 'upgrade', 'why')
    $options = @('--version', '--help', '-g', '--global', '--save-dev', '--save-prod', '--save-optional', '--frozen-lockfile')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'pnpm' -ScriptBlock $PnpmCompletion

#------------------------------------------------------------------------------
# Python/Pip Completions
#------------------------------------------------------------------------------

$PipCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('install', 'download', 'uninstall', 'freeze', 'list', 'show', 'search', 'check', 'config', 'cache', 'index', 'wheel', 'hash', 'completion', 'debug', 'help')
    $options = @('--version', '--help', '--upgrade', '-U', '--user', '--force-reinstall', '--no-deps', '--pre', '--require-virtualenv')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'pip' -ScriptBlock $PipCompletion
Register-ToolCompletion -Command 'pip3' -ScriptBlock $PipCompletion

#------------------------------------------------------------------------------
# .NET CLI Completions
#------------------------------------------------------------------------------

$DotnetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('new', 'restore', 'build', 'publish', 'run', 'test', 'pack', 'migrate', 'clean', 'sln', 'store', 'help', 'add', 'remove', 'list', 'tool', 'nuget', 'msbuild', 'vstest', 'watch', 'format', 'workload', 'sdk')
    $options = @('--version', '--info', '--list-runtimes', '--list-sdks', '--help', '-v', '--verbosity', '-c', '--configuration', '-f', '--framework', '--runtime')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'dotnet' -ScriptBlock $DotnetCompletion

#------------------------------------------------------------------------------
# Docker Completions
#------------------------------------------------------------------------------

$DockerCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('attach', 'build', 'builder', 'commit', 'compose', 'config', 'container', 'context', 'cp', 'create', 'diff', 'events', 'exec', 'export', 'history', 'image', 'images', 'import', 'info', 'inspect', 'kill', 'load', 'login', 'logout', 'logs', 'manifest', 'network', 'node', 'pause', 'plugin', 'port', 'ps', 'pull', 'push', 'rename', 'restart', 'rm', 'rmi', 'run', 'save', 'search', 'secret', 'service', 'stack', 'start', 'stats', 'stop', 'swarm', 'system', 'tag', 'top', 'trust', 'unpause', 'update', 'version', 'volume', 'wait')
    $options = @('--version', '--help', '-v', '--verbose', '-H', '--host', '--config', '--tls', '--tlscacert', '--tlscert', '--tlskey', '--tlsverify')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'docker' -ScriptBlock $DockerCompletion

#------------------------------------------------------------------------------
# Git Completions (enhanced)
#------------------------------------------------------------------------------

$GitCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('add', 'branch', 'checkout', 'clone', 'commit', 'config', 'diff', 'fetch', 'init', 'log', 'merge', 'mv', 'pull', 'push', 'rebase', 'reset', 'restore', 'rm', 'show', 'stash', 'status', 'switch', 'tag', 'bisect', 'cherry-pick', 'clean', 'describe', 'format-patch', 'gc', 'grep', 'help', 'notes', 'prune', 'reflog', 'remote', 'rerere', 'revert', 'shortlog', 'submodule', 'subtree', 'whatchanged', 'worktree')
    $options = @('--version', '--help', '--verbose', '--quiet', '--all', '--force', '--dry-run', '--porcelain', '--short')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'git' -ScriptBlock $GitCompletion

#------------------------------------------------------------------------------
# Kubernetes (kubectl) Completions
#------------------------------------------------------------------------------

$KubectlCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('get', 'describe', 'create', 'delete', 'apply', 'run', 'expose', 'set', 'edit', 'rollout', 'scale', 'autoscale', 'certificate', 'cluster-info', 'top', 'cordon', 'uncordon', 'drain', 'taint', 'label', 'annotate', 'completion', 'api-resources', 'api-versions', 'config', 'plugin', 'version', 'proxy', 'cp', 'auth', 'debug', 'events', 'exec', 'logs', 'port-forward', 'attach', 'wait')
    $options = @('--namespace', '-n', '--all-namespaces', '-A', '--output', '-o', '--selector', '-l', '--all', '--watch', '-w', '--show-labels', '--context')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'kubectl' -ScriptBlock $KubectlCompletion

#------------------------------------------------------------------------------
# Helm Completions
#------------------------------------------------------------------------------

$HelmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('completion', 'create', 'dependency', 'env', 'get', 'history', 'install', 'lint', 'list', 'package', 'plugin', 'pull', 'push', 'repo', 'rollback', 'search', 'show', 'status', 'template', 'test', 'uninstall', 'upgrade', 'verify', 'version')
    $options = @('--namespace', '-n', '--kube-context', '--kubeconfig', '--debug', '--help', '--version', '-v', '--repo', '--values', '-f', '--set', '--wait', '--timeout')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'helm' -ScriptBlock $HelmCompletion

#------------------------------------------------------------------------------
# VS Code CLI Completions
#------------------------------------------------------------------------------

$CodeCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $options = @('--help', '--version', '-v', '--verbose', '--diff', '--merge', '--goto', '--new-window', '-n', '--reuse-window', '-r', '--wait', '-w', '--disable-extensions', '--list-extensions', '--show-versions', '--install-extension', '--uninstall-extension', '--enable-proposed-api', '--status', '--statuses', '--sync', '--export', '--telemetry', '--disable-telemetry', '--crash-reporter-directory', '--extensions-dir', '--user-data-dir', '--portable', '--enable-proposed-api', '--log', '--max-memory', '--turn-off-sync')

    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'code' -ScriptBlock $CodeCompletion

#------------------------------------------------------------------------------
# Terraform Completions
#------------------------------------------------------------------------------

$TerraformCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('apply', 'console', 'destroy', 'env', 'fmt', 'force-unlock', 'get', 'graph', 'import', 'init', 'login', 'logout', 'metadata', 'output', 'plan', 'providers', 'refresh', 'show', 'state', 'taint', 'test', 'untaint', 'validate', 'version', 'workspace')
    $options = @('--version', '--help', '-chdir', '-json', '-var', '-var-file', '-out', '-auto-approve', '-input', '-lock', '-lock-timeout', '-parallelism', '-refresh', '-target', '-upgrade', '-check', '-diff', '-recursive', '-write')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'terraform' -ScriptBlock $TerraformCompletion

#------------------------------------------------------------------------------
# AWS CLI Completions
#------------------------------------------------------------------------------

$AwsCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $services = @('accessanalyzer', 'account', 'acm', 'acm-pca', 'amp', 'amplify', 'amplifybackend', 'amplifyuibuilder', 'apigateway', 'apigatewaymanagementapi', 'apigatewayv2', 'appconfig', 'appconfigdata', 'appfabric', 'appflow', 'appintegrations', 'application-autoscaling', 'application-insights', 'applicationcostprofiler', 'appmesh', 'apprunner', 'appstream', 'appsync', 'arc-zonal-shift', 'athena', 'auditmanager', 'autoscaling', 'autoscaling-plans', 'b2bi', 'backup', 'backup-gateway', 'backupstorage', 'batch', 'bedrock', 'bedrock-agent', 'bedrock-agent-runtime', 'bedrock-runtime', 'billingconductor', 'braket', 'budgets', 'ce', 'chatbot', 'chime', 'chime-sdk-identity', 'chime-sdk-media-pipelines', 'chime-sdk-meetings', 'chime-sdk-messaging', 'chime-sdk-voice', 'cleanrooms', 'cloud9', 'cloudcontrol', 'clouddirectory', 'cloudformation', 'cloudfront', 'cloudfront-keyvaluestore', 'cloudhsm', 'cloudhsmv2', 'cloudsearch', 'cloudsearchdomain', 'cloudtrail', 'cloudtrail-data', 'cloudwatch', 'codeartifact', 'codebuild', 'codecatalyst', 'codecommit', 'codedeploy', 'codeguru-reviewer', 'codeguru-security', 'codeguruprofiler', 'codepipeline', 'codestar', 'codestar-connections', 'codestar-notifications', 'cognito-identity', 'cognito-idp', 'cognito-sync', 'comprehend', 'comprehendmedical', 'compute-optimizer', 'configservice', 'configure', 'connect', 'connect-contact-lens', 'connectcases', 'connectparticipant', 'controltower', 'cur', 'customer-profiles', 'databrew', 'dataexchange', 'datapipeline', 'datasync', 'dax', 'deploy', 'detective', 'devicefarm', 'devops-guru', 'directconnect', 'discovery', 'dlm', 'dms', 'docdb', 'docdb-elastic', 'drs', 'ds', 'dynamodb', 'dynamodbstreams', 'ebs', 'ec2', 'ec2-instance-connect', 'ecr', 'ecr-public', 'ecs', 'efs', 'eks', 'eks-auth', 'elasticache', 'elasticbeanstalk', 'elastictranscoder', 'elb', 'elbv2', 'emr', 'emr-containers', 'emr-serverless', 'entityresolution', 'es', 'events', 'evidently', 'finspace', 'finspace-data', 'firehose', 'fis', 'fms', 'forecast', 'forecastquery', 'frauddetector', 'fsx', 'gamelift', 'glacier', 'globalaccelerator', 'glue', 'grafana', 'greengrass', 'greengrassv2', 'groundstation', 'guardduty', 'health', 'healthlake', 'history', 'iam', 'identitystore', 'imagebuilder', 'importexport', 'inspector', 'inspector2', 'internetmonitor', 'iot', 'iot-data', 'iot-jobs-data', 'iot-roborunner', 'iot1click-devices', 'iot1click-projects', 'iotanalytics', 'iotdeviceadvisor', 'iotevents', 'iotevents-data', 'iotfleethub', 'iotfleetwise', 'iotsecuretunneling', 'iotsitewise', 'iotthingsgraph', 'iotwireless', 'ivs', 'ivs-realtime', 'ivschat', 'kafka', 'kafkaconnect', 'kendra', 'kendra-ranking', 'keyspaces', 'kinesis', 'kinesis-video-archived-media', 'kinesis-video-media', 'kinesis-video-signaling', 'kinesis-video-webrtc-storage', 'kinesisanalytics', 'kinesisanalyticsv2', 'kinesisvideo', 'kms', 'lakeformation', 'lambda', 'launch-wizard', 'lex-models', 'lex-runtime', 'lexv2-models', 'lexv2-runtime', 'license-manager', 'license-manager-linux-subscriptions', 'license-manager-user-subscriptions', 'lightsail', 'location', 'logs', 'lookoutequipment', 'lookoutmetrics', 'lookoutvision', 'm2', 'machinelearning', 'macie2', 'managedblockchain', 'managedblockchain-query', 'marketplace-catalog', 'marketplace-entitlement', 'marketplacecommerceanalytics', 'mediaconnect', 'mediaconvert', 'medialive', 'mediapackage', 'mediapackage-vod', 'mediapackagev2', 'mediastore', 'mediastore-data', 'mediatailor', 'medical-imaging', 'memorydb', 'meteringmarketplace', 'mgh', 'mgn', 'migration-hub-refactor-spaces', 'migrationhub-config', 'migrationhuborchestrator', 'migrationhubstrategy', 'mq', 'mturk', 'mwaa', 'neptune', 'neptune-graph', 'neptunedata', 'network-firewall', 'networkmanager', 'nimble', 'oam', 'omics', 'opensearch', 'opensearchserverless', 'opsworks', 'opsworks-cm', 'organizations', 'osis', 'outposts', 'panorama', 'payment-cryptography', 'payment-cryptography-data', 'pca-connector-ad', 'personalize', 'personalize-events', 'personalize-runtime', 'pi', 'pinpoint', 'pinpoint-email', 'pinpoint-sms-voice', 'pinpoint-sms-voice-v2', 'pipes', 'polly', 'pricing', 'privatenetworks', 'proton', 'qldb', 'qldb-session', 'quicksight', 'ram', 'rbin', 'rds', 'rds-data', 'redshift', 'redshift-data', 'redshift-serverless', 'rekognition', 'resiliencehub', 'resource-explorer-2', 'resource-groups', 'resourcegroupstaggingapi', 'robomaker', 'rolesanywhere', 'route53', 'route53-recovery-cluster', 'route53-recovery-control-config', 'route53-recovery-readiness', 'route53domains', 'route53resolver', 'rum', 's3', 's3api', 's3control', 's3outposts', 'sagemaker', 'sagemaker-a2i-runtime', 'sagemaker-edge', 'sagemaker-featurestore-runtime', 'sagemaker-geospatial', 'sagemaker-metrics', 'sagemaker-runtime', 'savingsplans', 'scheduler', 'schemas', 'sdb', 'secretsmanager', 'securityhub', 'securitylake', 'serverlessrepo', 'service-quotas', 'servicecatalog', 'servicecatalog-appregistry', 'servicediscovery', 'ses', 'sesv2', 'shield', 'signer', 'simspaceweaver', 'sms', 'snow-device-management', 'snowball', 'sns', 'sqs', 'ssm', 'ssm-contacts', 'ssm-incidents', 'ssm-sap', 'sso', 'sso-admin', 'sso-oidc', 'stepfunctions', 'storagegateway', 'sts', 'support', 'support-app', 'swf', 'synthetics', 'textract', 'timestream-query', 'timestream-write', 'tls', 'transcribe', 'transfer', 'translate', 'verifiedpermissions', 'voice-id', 'vpc-lattice', 'waf', 'waf-regional', 'wafv2', 'wellarchitected', 'wisdom', 'workdocs', 'worklink', 'workmail', 'workmailmessageflow', 'workspaces', 'workspaces-web', 'xray')

    $services | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'aws' -ScriptBlock $AwsCompletion

#------------------------------------------------------------------------------
# Azure CLI Completions
#------------------------------------------------------------------------------

$AzCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('account', 'acr', 'ad', 'aks', 'apim', 'appconfig', 'appservice', 'backup', 'batch', 'billing', 'bot', 'cdn', 'cloud', 'cognitiveservices', 'config', 'configure', 'consumption', 'container', 'cosmosdb', 'deployment', 'disk', 'dla', 'dls', 'dms', 'eventgrid', 'eventhubs', 'extension', 'feedback', 'find', 'functionapp', 'group', 'hdinsight', 'identity', 'image', 'iot', 'keyvault', 'kusto', 'lab', 'lock', 'login', 'logout', 'managedapp', 'maps', 'mariadb', 'monitor', 'mysql', 'netappfiles', 'network', 'policy', 'postgres', 'ppg', 'provider', 'redis', 'relay', 'resource', 'role', 'search', 'security', 'servicebus', 'sf', 'signalr', 'snapshot', 'sql', 'sqlvm', 'ssh', 'storage', 'synapse', 'tag', 'term', 'ts', 'version', 'vm', 'vmss', 'webapp', 'webpubsub', 'workloads')
    $options = @('--version', '--help', '--verbose', '--debug', '--query', '--output', '-o', '--subscription', '-s', '--resource-group', '-g', '--location', '-l')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'az' -ScriptBlock $AzCompletion

#------------------------------------------------------------------------------
# GH (GitHub CLI) Completions
#------------------------------------------------------------------------------

$GhCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('alias', 'api', 'auth', 'browse', 'codespace', 'completion', 'config', 'extension', 'gpg-key', 'issue', 'label', 'org', 'pr', 'project', 'release', 'repo', 'run', 'search', 'secret', 'ssh-key', 'status', 'variable', 'workflow')
    $options = @('--version', '--help', '--repo', '-R', '--hostname', '--silent', '--jq', '--json', '--template', '--paginate', '-p')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'gh' -ScriptBlock $GhCompletion

#------------------------------------------------------------------------------
# Rust/Cargo Completions
#------------------------------------------------------------------------------

$CargoCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('add', 'bench', 'build', 'check', 'clean', 'clippy', 'doc', 'fetch', 'fix', 'fmt', 'generate-lockfile', 'init', 'install', 'locate-project', 'login', 'logout', 'metadata', 'new', 'owner', 'package', 'pkgid', 'publish', 'remove', 'report', 'run', 'rustdoc', 'search', 'test', 'tree', 'uninstall', 'update', 'vendor', 'verify-project', 'version', 'yank')
    $options = @('--version', '--help', '--verbose', '-v', '--quiet', '-q', '--color', '--frozen', '--locked', '--offline', '-p', '--package', '--workspace', '--all', '--exclude', '--lib', '--bin', '--bins', '--example', '--examples', '--test', '--tests', '--bench', '--benches', '--all-targets', '--features', '--all-features', '--no-default-features', '--target', '--release', '-r', '--profile', '--debug', '--jobs', '-j')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'cargo' -ScriptBlock $CargoCompletion

#------------------------------------------------------------------------------
# NuGet Completions
#------------------------------------------------------------------------------

$NugetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('add', 'client-cert', 'config', 'delete', 'disable', 'enable', 'init', 'install', 'list', 'locals', 'push', 'remove', 'restore', 'search', 'setApiKey', 'sign', 'sources', 'spec', 'trustedsigners', 'update', 'verify')
    $options = @('--version', '--help', '--source', '--configfile', '--output-directory', '-OutputDirectory', '--exclude-version', '-ExcludeVersion', '--disable-parallel-processing', '--no-cache', '--require-consent', '--non-interactive', '--verbosity', '-Verbosity')

    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'nuget' -ScriptBlock $NugetCompletion

#------------------------------------------------------------------------------
# Profile command argument completers
#------------------------------------------------------------------------------

Register-ArgumentCompleter -CommandName Set-DnsProfile -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    try {
        Initialize-NetworkProfiles | Out-Null
        foreach ($profileName in $Global:ProfileConfig.NetworkProfiles.Keys) {
            if ($profileName -like "$wordToComplete*") {
                [System.Management.Automation.CompletionResult]::new($profileName, $profileName, 'ParameterValue', $profileName)
            }
        }
    } catch {
        Write-ProfileLog "DNS profile completion initialization failed: $($_.Exception.Message)" -Level DEBUG -Component "Completions"
    }
}

Register-ArgumentCompleter -CommandName Set-PowerPlan -ParameterName Plan -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    @('Balanced', 'HighPerformance', 'PowerSaver') |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

#------------------------------------------------------------------------------
# Initialize all completions
#------------------------------------------------------------------------------

Write-ProfileLog "Tool completions registered" -Level DEBUG -Component "Completions"

} else {
    Write-ProfileLog "Tool completions skipped (non-interactive or disabled)" -Level DEBUG -Component "Completions"
}

#endregion TOOL INTEGRATIONS AND CODE COMPLETIONS

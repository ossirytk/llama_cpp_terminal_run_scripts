
$MAIN_CFG = Get-Content -Path .\main.json | ConvertFrom-Json
$EXE_PATH = $MAIN_CFG.llama_cpp_path
$EXE_BIN = $EXE_PATH + "main.exe"
If (-Not (Test-Path $EXE_PATH)) 
{
  Throw "The exe path does not exist, please specify an existing directory"
}

If (-Not (Test-Path $EXE_BIN)) 
{
  Throw "Could not find exe. Did you forget to build?"
}

#Check if we have the params fro last run
$last_run = $MAIN_CFG.cache_path + "last.json"
if(Test-Path $last_run) {
  try {
    $params = Get-Content $last_run | ConvertFrom-Json
    $last_model = Split-Path $params[5] -Leaf
    $last_prompt = Split-Path $params[7] -Leaf
    $question = $last_model + "`r`nPrompt: " + $last_prompt +"`r`n"
    $rerun_choice = $Host.UI.PromptForChoice("Rerun last chat?", $question, @("&Yes","&No"), 0)
    if($rerun_choice -eq 0){
      & $EXE_BIN @params
    }
  }
  catch {
    Write-Host "Could not load cache"
  }
}


#Build a list of model files
$path = $MAIN_CFG.model_path + "*.gguf"
try {
  $files = Get-ChildItem $path | ForEach-Object {
    if ( -not $_.psiscontainer) {
        $temp = $_.fullname -replace [regex]::escape($path), (split-path $path -leaf)
        "$temp"
    }
}
}
catch {
  Throw "Error loading model list"
}
$choices = [System.Collections.ArrayList]@()
$i = 0
#Build list for the choice prompt.
foreach($item in $files)
{
    #add returns an index that is echoed so just catch it
    $file_name = Split-Path $item -Leaf
    $_id = $choices.Add("$file_name" + "[&$i]")
    ++$i
}
#Model selection prompt
#TODO: This has issues when selection is greater than 9. Rework to support large choice lists
[System.Management.Automation.Host.ChoiceDescription[]]$choicelist = $choices
$choice = $Host.UI.PromptForChoice("Please select a model to load", "What do you want?", $choicelist, 0)

#If only one settings file in list then this returns a string
if ($files.GetType().FullName -eq "System.String"){
  $model_file_name = Split-Path $files -Leaf
} else {
  $model_file_name = Split-Path $files[$choice] -Leaf
}

#Match the model name to a config file
$config_file_name = [System.IO.Path]::GetFileNameWithoutExtension($model_file_name) + ".json"

$model_config_path =$MAIN_CFG.model_config_path + $config_file_name
try {
  $MODEL_CFG = Get-Content -Path $model_config_path | ConvertFrom-Json
}catch {
  Throw "Error loading model config"
}

$settings_path = $MAIN_CFG.settings_path + "*.json"
try {
  $settings_files = Get-ChildItem $settings_path | ForEach-Object {
    if ( -not $_.psiscontainer) {
        $temp = $_.fullname -replace [regex]::escape($MAIN_CFG.settings_path), (split-path $MAIN_CFG.settings_path -leaf)
        "$temp"
    }
  }
}
catch {
  Throw "Error loading settings files"
}

$settings_choices = [System.Collections.ArrayList]@()
$i = 0
foreach($setting_file in $settings_files)
{
  #add returns an index that is echoed so just catch it
  $fileName = Split-Path $setting_file -Leaf
  $_id = $settings_choices.Add("$fileName" + "[&$i]")
  ++$i
}
#settings prompt
Write-Host 'Model: ' $model_file_name
[System.Management.Automation.Host.ChoiceDescription[]]$settings_choice_list = $settings_choices
$setting_choice = $Host.UI.PromptForChoice("Please select run settings", "What setting do you want to use?", $settings_choice_list, 0)

#If only one settings file in list then this returns a string
try {
  if ($settings_files.GetType().FullName -eq "System.String"){
    $SETTINGS_CFG = Get-Content -Path $settings_files | ConvertFrom-Json
    $settings_file_name = Split-Path $settings_files -Leaf
  } else {
    $SETTINGS_CFG = Get-Content -Path $settings_files[$setting_choice]| ConvertFrom-Json
    $settings_file_name = Split-Path $settings_files[$setting_choice] -Leaf
  }
}
catch {
  Throw "Error loading settings"
}

#Get prompts
$prompt_path = $MAIN_CFG.prompt_path + "*"
try {
  $prompts = Get-ChildItem $prompt_path -Include *.txt | ForEach-Object {
    if ( -not $_.psiscontainer) {
        $temp = $_.fullname -replace [regex]::escape($prompt_path), (split-path $prompt_path -leaf)
        "$temp"
    }
  }
  $prompts_json = Get-ChildItem $prompt_path -Include *.json | ForEach-Object {
    if ( -not $_.psiscontainer) {
        $temp = $_.fullname -replace [regex]::escape($prompt_path), (split-path $prompt_path -leaf)
        "$temp"
    }
  }
}
catch {
  Throw "Error loading prompt list"
}

#If there is just one prompt file of a given type the return element type is string
#So change to an array and combine the arrays
if ($prompts.GetType().FullName -eq "System.String"){
  $prompts = @($prompts)
}
if ($prompts_json.GetType().FullName -eq "System.String"){
  $prompts_json = @($prompts_json)
}

$prompts += $prompts_json
$prompt_choices = [System.Collections.ArrayList]@()

$i = 0
#Build list for the choice prompt.
foreach($prompt in $prompts)
{
    #add returns an index that is echoed so just catch it
    $prompt_name = Split-Path $prompt -Leaf
    $_id = $prompt_choices.Add("$prompt_name" + "[&$i]")
    ++$i
}

#Prompt prompt ;)
Write-Host 'Model: ' $model_file_name
Write-Host 'Settings: ' $settings_file_name
[System.Management.Automation.Host.ChoiceDescription[]]$prompt_choicelist = $prompt_choices
$prompt_choice = $Host.UI.PromptForChoice("Please select a prompt", "Which prompt do you want?", $prompt_choicelist, 0)
$prompt_name = Split-Path $prompts[$prompt_choice] -Leaf

$MODEL_PATH = $MAIN_CFG.model_path
$PROMPT_PATH = $MAIN_CFG.prompt_path

If (-Not (Test-Path $MODEL_PATH )) 
{
  Throw "The model path does not exist, please specify an existing directory"
}
If (-Not (Test-Path $PROMPT_PATH)) 
{
  Throw "The prompt path does not exist, please specify an existing directory"
}

$MODEL_NAME = $MODEL_CFG.model_name
$MODEL_PROMPT = $MODEL_PATH + $MODEL_NAME
$PARAM_PROMPT = $PROMPT_PATH + $prompt_name
If (-Not (Test-Path $MODEL_PROMPT )) 
{
  Throw "Could not find the model. Check that it exists."
}
If (-Not (Test-Path $PARAM_PROMPT)) 
{
  Throw "Could not find the prompt file. Check that it exists."
}

$LAYERS = $MODEL_CFG.layers
$THREADS = $MODEL_CFG.threads
$CONTEXT_SIZE = $MODEL_CFG.context_size
$N_PREDICT = $MODEL_CFG.n_predict

$TEMP = $SETTINGS_CFG.temperature
$REPEAT_PENALTY = $SETTINGS_CFG.repeat_penalty
$REPEAT_LAST = $SETTINGS_CFG.repeat_last
$BATCH_SIZE = $SETTINGS_CFG.batch_size
$ROPE_SCALE = $SETTINGS_CFG.rope_scale
$REVERSE_PROMPT = $MAIN_CFG.name + ":"

$cache_file =$MAIN_CFG.cache_path + [System.IO.Path]::GetFileNameWithoutExtension($model_file_name) + "_" +[System.IO.Path]::GetFileNameWithoutExtension($prompt_name) + ".gguf"

Write-Host "Running"
Write-Host 'Model: ' $model_file_name
Write-Host 'Settings: ' $settings_file_name
Write-Host 'Prompt: ' $prompt_name

$prompt_template = Get-Content -Path $PARAM_PROMPT
$extension = [System.IO.Path]::GetExtension($prompt_name)
if($extension -eq ".json") {
  try {
    ##TODO this sometimes fails even if the content is valid JSON. Figure out why
    $json_content = ConvertFrom-Json $prompt_template -AsHashtable
  }
  catch {
    throw 'Error loading Json'
  }
  
  if($json_content.ContainsKey("name")) {
      $name  = $json_content["name"]
  } else {
      $name  = $json_content["char_name"]
  }
  if($json_content.ContainsKey("description")) {
      $description = $json_content["description"]
  } else {
      $description = $json_content["char_persona"]
  }
  if($json_content.ContainsKey("scenario")) {
      $scenario = $json_content["scenario"]
  } else {
      $scenario = $json_content["world_scenario"]
  }
  if($json_content.ContainsKey("mes_example")) {
      $example_dialogue = $json_content["mes_example"]
  } else {
      $example_dialogue = $json_content["example_dialogue"]
  }
  if($json_content.ContainsKey("first_mes")) {
      $char_greeting = $json_content["first_mes"]
  } else {
      $char_greeting = $json_content["char_greeting"]
  }
  if($MODEL_CFG.model_type -eq "alpaca") {
    $pre_prompt = "### Instruction:`r`n" + $MAIN_CFG.prompt_core + "`r`n###Input:"
  } else {
    $pre_prompt = $MAIN_CFG.prompt_core
  }

  $processed_template =  $pre_prompt+ "`r`n" +$description + "`r`n" + $example_dialogue + "`r`n" + $scenario + "`r`n" + $char_greeting + "`r`n"
} else {
  $processed_template =  $prompt_template
}
$processed_template =  $processed_template.Replace("{{user}}", $MAIN_CFG.name).Replace("{{char}}", $name)
$temp_prompt_path =$MAIN_CFG.cache_path + [System.IO.Path]::GetFileNameWithoutExtension($prompt_name) + ".txt"
Out-File -FilePath $temp_prompt_path -InputObject $processed_template
##TODO construct this dynamically from the settings params
##Add extra params
##Enable bin and gguf
$params = [System.Collections.ArrayList]@(
    '-t'
    $THREADS
    '-ngl'
    $LAYERS
    '-m'
    $MODEL_PROMPT
    '-f'
    $temp_prompt_path
    '--color'
    '-c'
    $CONTEXT_SIZE
    '--temp'
    $TEMP
    '--repeat_penalty'
    $REPEAT_PENALTY
    '-n'
    $N_PREDICT
    '--no-penalize-nl'
    '--repeat_last_n'
    $REPEAT_LAST
    '--batch_size'
    $BATCH_SIZE
    "--rope_scale"
    $ROPE_SCALE
    '--interactive-first'
    '--in-prefix'
    $REVERSE_PROMPT
    "--reverse-prompt"
    $REVERSE_PROMPT
    "--prompt-cache"
    $cache_file
)
$startup_params = $params | ConvertTo-Json
Out-File -FilePath $last_run -InputObject $startup_params
& $EXE_BIN @params
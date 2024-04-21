#!/bin/bash

# Pull in your Stability AI key...
if [ -f ./.env ]; then
  echo "Loading API key from .env file..."
  source ./.env
else
  echo ".env file not found. Assuming environment variables are set elsewhere."
fi

if [ -z "${STABILITY_AI_KEY}" ]; then
  echo "STABILITY_AI_KEY is not set. Please define it in a .env file or in your shell profile."
  exit 1
fi

# Check dependencies are met:
# Check if jq, base64, and curl are installed and accessible
for cmd in jq base64 curl; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Command not found: $cmd. Please install it to continue."
    exit 1
  fi
done

# Initialize variables for optional parameters
negative_prompt=""
seed=""
filetype="jpeg" # Default filetype
output_file="image_$(date -u +%Y-%m-%dT%H%M%S)"
sd_model="sd3" # Default model.
accept_mode="application/json; type=image/jpeg"
aspect_ratio="16:9"

usage() {
  echo "Usage: $0 -p <prompt> [-n <negative prompt>] [-s <seed>] [-t <filetype>] [-o <output image file name without extension>] [-m <model>]"
  echo "Options:"
  echo "    -h: Print this help text."
  echo "    -p: Prompt string (required)."
  echo "        Must be between [0, 10000] characters long."
  echo "    -n: Negative prompt string (optional)."
  echo "        Maximum length of 10000 characters."
  echo "        Note: The 'sd3-turbo' model does not support negative prompts."
  echo "    -s: Seed value (optional). Must be in the range of [0, 4294967294]. Default is random."
  echo "    -t: Filetype (optional). Default is 'jpeg'. Choices are 'jpeg' or 'png'."
  echo "    -o: Name for the output image file (optional). Do not include an extension;"
  echo "        A timestamp and the appropriate file extension will be automatically appended, like so: ${output_file}.${filetype}"
  echo "    -m: Model choice (optional). Default is '${sd_model}'. Choices are 'sd3' or 'sd3-turbo'."
  echo "    -r: Aspect ratio (optional). Default is '${aspect_ratio}'. Choices are '16:9', '1:1', '21:9', '2:3', '3:2', '4:5', '5:4', '9:16', '9:21'."
  exit 0
}

interactive() {
  # Choose model.
  echo "Choose a model, or press enter to accept the default of \"${sd_model}\""
  echo "1) sd3"
  echo "2) sd3-turbo"
  printf ">>> "
  read input_value

  if [ -n "${input_value}" ]; then
    case ${input_value} in
      1 | sd3 )
        sd_model="sd3"
        ;;
      2 | sd3-turbo )
        sd_model="sd3-turbo"
        ;;
      * )
        echo "Invalid model selection."
        exit 2
        ;;
    esac
  fi
  unset input_value

    # Aspect ratio.
  echo "Choose an aspect ratio, or press ENTER to choose the default of '${aspect_ratio}'."
  while [ -z "${input_value}" ]; do
    echo "1) 16:9"
    echo "2) 1:1"
    echo "3) 21:9"
    echo "4) 2:3"
    echo "5) 3:2"
    echo "6) 4:5"
    echo "7) 5:4"
    echo "8) 9:16"
    echo "9) 9:21"
    printf ">>> "
    read input_value
    
    # Assume if 'input_value' is empty we're going with the default.
    if [ -n "${input_value}" ]; then
      # TODO: This needs to be moved to its own validator function.
      case "${input_value}" in
        1 | 16:9 )
          aspect_ratio="16:9"
          ;;
        2 | 1:1 )
          aspect_ratio="1:1"
          ;;
        3 | 21:9 )
          aspect_ratio="21:9"
          ;;
        4 | 2:3 )
          aspect_ratio="2:3"
          ;;
        5 | 3:2 )
          aspect_ratio="3:2"
          ;;
        6 | 4:5 )
          aspect_ratio="4:5"
          ;;
        7 | 5:4 )
          aspect_ratio="5:4"
          ;;
        8 | 9:16 )
          aspect_ratio="9:16"
          ;;
        9 | 9:21 )
          aspect_ratio="9:21"
          ;;
        exit )
          exit 0
          ;;
        * )
          echo "Invalid aspect ratio choice. Try again, or type 'exit' to exit."
          # By unsetting here, we can repeat the while loop.
          unset input_value
      esac
    else
      break
    fi
  done
  unset input_value

  # Choose seed.
  echo "Choose a seed, in the range [0, 4294967294]. Or press ENTER for random."
  printf ">>> "
  read input_value

  if [ -n "${input_value}" ]; then
    seed="${input_value}"
    # TODO: Move this to its own validation function for re-use. Putting this here was pure laziness.
    if [[ $((seed)) -lt 0 || $((seed)) -gt "4294967294" ]]; then
      echo "Seed must be in range [0, 4294967294]. Aborting."
      exit 2
    fi
  fi
  unset input_value

  # Choose filetype.
  echo "Choose the file type you want your image saved as, or press ENTER to accept the default value of \"${filetype}\"."
  echo "1) jpeg"
  echo "2) png"
  printf ">>> "
  read input_value

  if [ -n "${input_value}" ]; then
    case ${input_value} in
      1 | jpeg | jpg )
        filetype="jpeg"
        ;;
      2 | png )
        filetype="png"
        ;;
      * )
        echo "Invalid filetype."
        exit 2
        ;;
    esac
  fi
  accept_mode="application/json; type=image/${filetype}"
  unset input_value

  # Choose output filename.
  # TODO: Clean up instructions around output file name. Also probably change up how it appends the date, it's messy.
  echo "Choose a name for your image, or press ENTER to accept the default of ${output_file}.${filetype}."
  printf ">>> "
  read input_value

  if [ -n "${input_value}" ]; then
    output_file="${input_value}_$(date -u +%Y-%m-%dT%H%M%S)"
  fi
  unset input_value

  # Prompt.
  echo "Write your prompt here. Must be in the range of [1, 10000] characters."
  while [ -z "${input_value}" ]; do
    printf ">>> "
    read input_value
    # TODO: Move this to its own validation function.
    prompt_length=${#input_value}
    if [[ $((prompt_length)) -lt 1 || $((prompt_length)) -gt 10000 ]]; then
      echo "Prompt length must be in the range of [1, 10000] characters. Try again."
      unset input_value
    fi
  done
  prompt="${input_value}"
  unset input_value

  # Negative prompt. Only applies to 'sd3'.
  if [ "${sd_model}" != "sd3-turbo" ]; then
    echo "Write your negative prompt here, or press ENTER to skip entering one. Must be less than 10000 characters. Does not apply to sd3-turbo."
    printf ">>> "
    read input_value
    # TODO: Move this to its own validation function.
    negative_prompt_length=${#input_value}
    if [[ $((negative_prompt_length)) -gt 10000 ]]; then
      echo "Negative prompt length must be less than 10000 characters. Aborting."
      exit 2
    fi
    negative_prompt="${input_value}"
    unset input_value
  fi



  # TODO: Debug prints. Remove these later.
  # echo "Model: ${sd_model}"
  # echo "Aspect ratio: ${aspect_ratio}"
  # echo "Seed: ${seed}"
  # echo "Filetype: ${filetype}"
  # echo "Filename: ${output_file}"
  # echo "Prompt: ${prompt}"
  # echo "Negative prompt: ${negative_prompt}"
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    #usage
    interactive
fi

while getopts ":p:n:s:t:o:m:r:" opt; do
  case ${opt} in
    h )
      usage
      exit 0
      ;;
    p )
      prompt="${OPTARG}"
      prompt_length=${#prompt}
      if [[ $((prompt_length)) -lt 1 || $((prompt_length)) -gt 10000 ]]; then
        echo "Prompt length must be in the range of [1, 10000] characters. Aborting."
        exit 2
      fi
      ;;
    n )
      negative_prompt="${OPTARG}"
      negative_prompt_length=${#negative_prompt}
      if [[ $((negative_prompt_length)) -gt 10000 ]]; then
        echo "Negative prompt length must be less than 10000 characters. Aborting."
        exit 2
      fi
      ;;
    r )
      case "${OPTARG}" in
        1 | 16:9 )
          aspect_ratio="16:9"
          ;;
        2 | 1:1 )
          aspect_ratio="1:1"
          ;;
        3 | 21:9 )
          aspect_ratio="21:9"
          ;;
        4 | 2:3 )
          aspect_ratio="2:3"
          ;;
        5 | 3:2 )
          aspect_ratio="3:2"
          ;;
        6 | 4:5 )
          aspect_ratio="4:5"
          ;;
        7 | 5:4 )
          aspect_ratio="5:4"
          ;;
        8 | 9:16 )
          aspect_ratio="9:16"
          ;;
        9 | 9:21 )
          aspect_ratio="9:21"
          ;;
        exit )
          exit 0
          ;;
        * )
          echo "Invalid aspect ratio choice."
          exit 2;
      esac
      ;;
    s )
      seed="${OPTARG}"
      if [[ $((seed)) -lt 0 || $((seed)) -gt "4294967294" ]]; then
        echo "Seed must be in range [0, 4294967294]. Aborting."
        exit 2
      fi
      ;;
    t )
      filetype="${OPTARG}"
      if ! [[ "$filetype" == "jpeg" || "$filetype" == "png" ]]; then
        echo "Filetype must be jpeg or png. Aborting."
        exit 2
      fi
      # Set the file type accordingly for what we'll get back.
      accept_mode="application/json; type=image/${filetype}"
      ;;
    o )
      output_file="${OPTARG}_$(date -u +%Y-%m-%dT%H%M%S)"
      ;;
    m )
      sd_model="${OPTARG}"
      if ! [[ "$sd_model" == "sd3" || "$sd_model" == "sd3-turbo" ]]; then
        echo "Model must be 'sd3' or 'sd3-turbo'. Aborting."
        exit 2
      fi
      ;;
    \? )
      usage
      ;;
    : )
     echo "Option -$OPTARG requires an argument." >&2
     exit 1
     ;;
   esac
done

if [ -z "${prompt}" ]; then
   echo "Prompt is required."
   usage
fi

if [[ -n "${negative_prompt}" && "${sd_model}" == 'sd3-turbo' ]]; then
  echo "The sd3-turbo model does not support a negative prompt. Aborting."
  exit 2
fi

# Define a temporary file.
sd_temp_file="sd_temp_$(date -u +%Y-%m-%dT%H%M%S).json"

# Define your curl command as an array
curl_command=(
  curl -f -sS 'https://api.stability.ai/v2beta/stable-image/generate/sd3'
  -H "authorization: Bearer ${STABILITY_AI_KEY}"
  -H "accept: ${accept_mode}"
  -F "prompt=${prompt}"
  -F "model=${sd_model}"
  -F "negative_prompt=${negative_prompt}"
  -F "seed=${seed}"
  -F "output_format=${filetype}"
  -F "aspect_ratio=${aspect_ratio}"
  -o "${sd_temp_file}"
  -w '%{http_code}'
)

# Execute it directly
http_status="$("${curl_command[@]}")"

# Log file
log_file="${output_file}.md"

error_message=""

case "$http_status" in
  200)
    echo "All good! Image successfully retrieved. (Code 200)"
    # Handle the following:
    # - Extract base64-encoded image and save it to appropriate file type.
    # - Save seed, prompt, negative prompt, filename, filetype, and model choice to a text file.
    jq -r '.image' "${sd_temp_file}" | base64 --decode > ./"${output_file}.${filetype}"

    # Retrieve the seed value from the json file.
    seed=$(jq -r '.seed' "${sd_temp_file}")

    # Generate the log.
    {
      echo "# Image Generation Log for ${output_file}.${filetype}"
      echo "Filename: ${output_file}.${filetype}"
      echo "Seed: ${seed}"
      echo "Prompt: ${prompt}"
      echo "Negative Prompt: ${negative_prompt}"
      echo "Output Format: ${filetype}"
      echo "Model: ${sd_model}"
    } | tee -a "${log_file}"
    ;;
  400)
    error_message="Bad Request - The server cannot or will not process the request due to something that is perceived to be a client error (e.g., malformed request syntax, invalid request message framing, or deceptive request routing). See ERRORS for details. (Code 400)"
    ;;
  403)
    error_message="Forbidden - Your request was flagged by the Stable Diffusion API's content moderation system. (Code 403)"
    ;;
  413)
    error_message="Your request was larger than 10 MiB. (Code 413)"
    ;;
  429)
    error_message="Too Many Requests - Slow down cowboy! You're hitting the API too hard. Try again later. (Code 429)"
    ;;
  500)
    error_message="Internal Server Error - Something's borked on their end. Might want to grab a coffee and give them some time to fix whatever gremlin snuck into their servers. (Code 500)"
    ;;
  *)
    error_message="Unexpected status: $http_status. Undefined in API documentation."
esac

# Check if we're in an error state.
if [ "$http_status" != "200" ]; then
  echo "${error_message}"
  error_name=$(jq -r '.name' "${sd_temp_file}")
  error_list=$(jq -r '.errors[]' "${sd_temp_file}")

  echo "----------------"
  {
    echo "# Error Log for ${output_file} (Code ${http_status})"
    echo "Error Message: ${error_message}"
    echo "Filename: ${output_file}.${filetype}"
    echo "Prompt: ${prompt}"
    echo "Negative Prompt: ${negative_prompt}"
    echo "Otput Format: ${filetype}"
    echo "Model: ${sd_model}"
    echo "Info Returned by API:"
    echo "Error Name: ${error_name}"
    echo "Error List:"
    echo "${error_list}"
  } | tee ${log_file}
fi

# Remove the temporary file.
rm ./"${sd_temp_file}"

echo "Image saved as ${output_file}.${filetype}"

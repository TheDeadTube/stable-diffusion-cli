# stable-diffusion-cli

These scripts provide an easy way to interact with the Stability AI API via a Linux command-line interface (CLI), with proper error-handling and logging as much information as possible about each image. Part of what spurred this project was that I kept losing track of what prompts, negative prompts, and seeds I had used per image.

## Prerequisites

Before running this script, ensure you have the following dependencies installed:

- `curl`: For making API requests.
- `jq`: For parsing JSON responses.
- `base64`: For decoding base64-encoded images.

Most Unix-like operating systems include these by default. If not, they can be installed through your package manager (e.g., apt for Ubuntu/Debian, brew for macOS).

## Setting Up Your Environment

You need a valid API key from [Stability AI](https://platform.stability.ai/docs/getting-started). Once obtained:

### Option 1: In Your Shell Profile

Define it in your shell profile (e.g., `.bashrc`, `.zshrc`) on a new line, like so:

```bash
export STABILITY_AI_KEY='your_api_key_here'
```

### Option 2: .env File

Create a `.env` file in the same directory as this script and add the following to the top of the file:

```bash
STABILITY_AI_KEY=your_api_key_here
```

 A file, `env_template` has been included for your convenience.

Ensure that either method is set up correctly so the script can authenticate with Stability AI's services.

## Usage

Usage will be broken down per script. More will be added as time goes on.

### sd3-txt2img.sh

For running text-to-image calls on Stable Diffusion 3 and Stable Diffusion 3 Turbo.

To run the script:

```bash
./sd3-txt2img.sh [options]
```

Replace `[options]` with any command-line options detailed below.

#### Options

- `-p "prompt"`: *Required.* Sets the prompt for image generation. Must be between 1 and 10,000 characters in length.
- `-n "negative prompt"`: *Optional.* Sets the negative prompt for image generation. Note that only the `sd3` model supports a negative prompt. `sd3-turbo` does not. Cannot be more than 10,000 characters.
- `-s "integer value"`: *Optional.* Takes an integer value between `0` and `4294967294`.
- `-t "file type"`: *Optional.* Choices are `jpeg` and `png`. Default is `jpeg`.
- `-o "image name"`: *Optional.* The prefix to name your output image (and log file) with. A timestamp and the appropriate file extension will be automatically appended.
- `-m "model"`: *Optional.* Default is `sd3`. Choices are `sd3` and `sd3-turbo`.
- `-h`: Print the 'help' text.

## TODO / Roadmap

This section outlines planned enhancements and features we aim to implement. It serves as a rough roadmap for the project's development direction. Contributions and suggestions are welcome!

- [ ] Add aspect ratio selection to `sd3-txt2img.sh`.
- [ ] Implement interactive mode in `sd3-txt2img.sh` for easier prompt input.
- [ ] Support for additional Stability AI models beyond sd3 and sd3-turbo.
- [ ] Add support for batch processing of multiple prompts.
- [ ] Test compatibility with Windows systems via WSL (Windows Subsystem for Linux).
- [ ] Reticulate splines.

Please note that these items are subject to change based on user feedback and contributions. If you're interested in contributing or have suggestions, please see the "Contributing" section below.

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

Don't forget to give this project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

deadtube – [@TheDeadTube](https://twitter.com/TheDeadTube)

Project Link: [https://github.com/TheDeadTube/stable-diffusion-cli](https://github.com/TheDeadTube/stable-diffusion-cli)

## AIXCL Accelerated Software Engineering

### Overview

AIXCL is an AI-powered software development and engineering platform designed to accelerate and streamline the software development process.

**Key Features:**

- Code and test generation.
- Pull request and code review assistance.
- Standards enforcement and linting.
- Security scanning.
- Seamless integration with the IDE and CI/CD pipeline.

**Benefits:**

- Tooling: Write and edit code directly, receive context-aware suggestions, and train your own models.
- Actionable AI: Access pre-trained models for various tasks and customize them for your needs.
- Code Suggest: Autocomplete your code and receive debugging insights.
- GitHub AI: Improve code readability and maintainability.

### Technology Stack

- Open-source software and readily available Large Language Models (LLMs) form the foundation of the platform.
- Users can extend the platform with proprietary tooling as needed.


### Platform Specifications

**POC Platform:**

- Designed for teams of 3-5 developers.
- Uses 5-10 LLM models (7GB each).
- Runs on an AWS instance with a single GPU.


**AWS Instance:**

- Operating System: Ubuntu Linux
- Instance Type: [g4dn.xlarge](https://aws.amazon.com/ec2/instance-types/g4/)
- 4x CPU
- 1x GPU
- 16GB RAM
- Note: You should have at least 8 GB of RAM available to run the 7B models, 16 GB to run the 13B models, and 32 GB to run the 33B models.

**prerequisites:**

- Ubuntu Linux
- Docker
- Nvidia drivers and toolset

**Server Ports:**

- Ollama LLM: 11434
- Open WebUI: 3000
- SSH Access: 22

### Installation Instructions

To install the conternized bundle.
```
docker run --network="host" -d -p 3000:8080 --gpus=all -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama
```

Install the recommended LLM's.
```
docker exec -it open-webui ollama run llama3.1:latest
docker exec -it open-webui ollama run codellama:latest
docker exec -it open-webui ollama run gemma2:latest
docker exec -it open-webui ollama run nomic-embed-text:latest
docker exec -it open-webui ollama run starcoder2:latest
```

Check the containers are running.
```
docker ps
CONTAINER ID   IMAGE                                  COMMAND           CREATED          STATUS                    PORTS     NAMES
442ac8fbc2bc   ghcr.io/open-webui/open-webui:ollama   "bash start.sh"   17 minutes ago   Up 17 minutes (healthy)             open-webui
```

Check the endpoints are available with curl and look for status code 200 OK.
```
head -n1 <(curl -I http://localhost:11434 2> /dev/null)
HTTP/1.1 200 OK

head -n1 <(curl -I http://localhost:8080 2> /dev/null)
HTTP/1.1 200 OK
```

You can list the installed LLM with
```
docker exec -it open-webui ollama list
NAME                    ID              SIZE    MODIFIED    
gemma2:latest           ff02c3702f32    5.4 GB  7 hours ago
llama3.1:latest         42182419e950    4.7 GB  7 hours ago
nomic-embed-text:latest 0a109f422b47    274 MB  8 hours ago
starcoder:latest        847e5a7aa26f    1.8 GB  8 hours ago
```

At this stage the server is installed with Ollama, Open WebUI and the required LLMs.

You should now browse to your server instance via Open WebUI and use the signup button to create your admin account.
```
http://localhost:8080 
```

You can install the continue plugin via VSCode or using the following command.
```
code --install-extension continue.continue
```

### User AI Tooling:

**[Ollama](https://github.com/ollama/ollama) with [Open Webui](https://github.com/open-webui/open-webui)**

- Get up and running with Llama 3, Mistral, Gemma, and other large language models.
- Code Editor: Write and edit code directly within the UI.
- Model Selector: Choose from a variety of pre-trained AI models for different tasks.
- Input & Output: Input your data and review the model's outputs.
- Customization: Train your own models with your own data.
- Administer users and LMM access to your server.

**[Continue](https://docs.continue.dev/quickstart) VSCode plugin**

- Access AI models directly from your code editor.
- Get context-aware suggestions as you type.
- Train your own models and save them for future use.


### CICD Tooling:

**Actionable AI:**

- Provides pre-trained models for tasks like classification, summarization, and sentiment analysis.
- Offers custom model training and deployment options.
- Free for public repositories, paid for private repositories.


**AI Code Suggest:**

- Autocompletes code based on your typing and surrounding context.
- Learns from your coding style over time.
- Open-source.


**GitHub AI:**

- Improves code readability and maintainability.
- Analyzes code structure, naming, and documentation.
- Free for all GitHub users.


**CodeX:**

- Generates code from natural language descriptions.
- Offers code completion and debugging suggestions.
- Available as a GitHub Action and VS Code extension.

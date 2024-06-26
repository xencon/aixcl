## Kodexcl Platform Overview

### Overview

Kodexcl is an AI-powered software development platform designed to accelerate and streamline the software development process. Key features include:

- Automated test generation and code suggestions.
- AI-powered pull request and code review assistance.
- Seamless integration with the IDE and CI/CD pipeline.


### Technology Stack

- Open-source software and readily available AI language models (LLMs) form the foundation of the platform.
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
- Nvidia divers and toolset

**Server Ports:**

- 11434 Ollama
- 3000 Open WebUI
- 22 SSH Access

### Installation Instructions

Install Ollama and Open WebUI via docker.
```
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama --restart always
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

Check the containers are running.
```
docker ps
CONTAINER ID   IMAGE                                COMMAND               CREATED       STATUS                 PORTS                                           NAMES
b7537a67fee3   ghcr.io/open-webui/open-webui:main   "bash start.sh"       5 hours ago   Up 5 hours (healthy)   0.0.0.0:3000->8080/tcp, :::3000->8080/tcp       open-webui
ed45ab7c6770   ollama/ollama                        "/bin/ollama serve"   7 days ago    Up 7 hours             0.0.0.0:11434->11434/tcp, :::11434->11434/tcp   ollama
```

Check the endpoints are available with curl and look for status code 200 OK.
```
head -n1 <(curl -I http://www.example.com:11434 2> /dev/null)
HTTP/1.1 200 OK

head -n1 <(curl -I http://www.example.com:3000 2> /dev/null)
HTTP/1.1 200 OK
```

Install the LLM.
```
docker exec -it ollama ollama run llama3
>>> Send a message (/? for help
```

Exit the LLM prompt with CTRL-D

You can list the installed LLM with
```
docker exec -it ollama ollama list
NAME                    ID              SIZE    MODIFIED   
llama3:latest           365c0bd3c000    4.7 GB  7 days ago
```

At this stage the server is installed with Ollama, Open WebUI and The Meta LLama3 LLM.

You should now browse to your server instance via Open WebUI and use the signup button to create your admin account.
```
http://www.example.com:3000 
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


**Other Notable Options:**

- GitHub Actions - AI/ML
- DataCamp AI
- ModelFlow


**Resources:**

- GitHub Marketplace: AI & ML: https://marketplace.github.com/collections/ai-ml
- AI for GitHub Actions: https://blog.github.com/announcements/ai-github-actions/
- List of AI GitHub Actions: https://github.com/marketplace/actions?q=ai

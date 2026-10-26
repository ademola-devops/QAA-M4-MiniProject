Two tier application with an Express Backend and an nginx frontend with custom html and js files added. 
Ports required are: 80, 5000 and will require the use of DNS resolution.

Total project will include:
- Finishing Dockerfiles and building Docker Images
- Separate instance with Jenkins installed as a CI CD Server
- Kubernetes cluster with a deployment of 2x backend pods and 2x frontend pods


Your task is to setup a complete CI CD pipeline using Jenkins to Build Docker Images for an app and deploy using Kubernetes. Repo https://github.com/Reece-elder/QAA-M4-MiniProject

The app contains an Express backend with a single route sending a Hex colour code. The frontend is an index.html and index.js using a get request to access the hex colour code from the backend and changing the header.

You will need to use nginx to host the index.html and index.js files and modify the files so they can access the backend correctly.

The backend runs from express which is installed and ran via node, you will need node installed as well as all dependencies (which can be installed via the package.json file and using npm install).

The project should eventually be deployed to run on Kubernetes using pods for the backend and frontend images, a clusterIP for communication between pods and a load balancer for external communication to the frontend pod.

Jenkins should be used to setup a simple CI CD pipeline which is triggered via a Git Webhook. The Pipeline should do the following things:

--> Setup the files and clone down the latest files
--> Build the Docker images for backend and frontend
--> Push the images to a docker repository (DockerHub)
--> Deploy the images to a deployment of 2x front end pods and 2x backend pods

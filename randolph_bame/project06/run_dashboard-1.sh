
#!/bin/bash

echo Building docker image
docker build -t baltimore_dashboard .

echo Running dashboard
docker run -p 3838:3838 baltimore_dashboard

echo Open browser at http://localhost:3838

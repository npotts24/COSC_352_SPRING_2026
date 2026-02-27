# GitHub Setup Instructions

## Step 1: Create a New GitHub Repository

1. Go to https://github.com and log in
2. Click the "+" icon in the top right, then "New repository"
3. Name it: `baltimore-homicide-analysis`
4. Description: "R-based analysis of Baltimore City homicide data with Docker containerization"
5. Choose "Public" (or Private if preferred)
6. **DO NOT** initialize with README, .gitignore, or license (we already have these)
7. Click "Create repository"

## Step 2: Initialize Git and Push Your Code

Open a terminal in the project directory and run:

```bash
# Initialize git repository
git init

# Add all files
git add .

# Commit the files
git commit -m "Initial commit: Baltimore homicide analysis project"

# Add your GitHub repository as remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/baltimore-homicide-analysis.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Verify Upload

1. Refresh your GitHub repository page
2. You should see all files:
   - histogram.R
   - Dockerfile
   - run.sh
   - README.md
   - .gitignore

## Step 4: Test the Project

To verify everything works, you can clone the repo on another machine and run:

```bash
git clone https://github.com/YOUR_USERNAME/baltimore-homicide-analysis.git
cd baltimore-homicide-analysis
./run.sh
```

## Troubleshooting

### If `run.sh` doesn't execute:
```bash
chmod +x run.sh
./run.sh
```

### If git push requires authentication:
- Use a Personal Access Token instead of password
- Or set up SSH keys with GitHub

### If Docker isn't installed:
- Install Docker Desktop from https://www.docker.com/products/docker-desktop

## Next Steps

After uploading to GitHub:
1. Add badges to your README (build status, etc.)
2. Create issues for future improvements
3. Add contributing guidelines if working with others
4. Test that `./run.sh` works from a fresh clone

## Submission

When submitting to your professor:
- Provide the GitHub repository URL
- Ensure the repository is public or give professor access
- Include the README.md with your analysis justification

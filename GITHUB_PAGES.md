# GitHub Pages Deployment Guide

This guide explains how to deploy your Backstorie WASM application to GitHub Pages.

## Option 1: Using /docs Directory (Recommended)

GitHub Pages can serve directly from a `/docs` folder, which keeps your repository organized.

### Setup

1. **Compile to docs directory:**
   ```bash
   ./compile_wasm.sh -o docs -r
   ```

2. **Configure GitHub Pages:**
   - Go to your repository on GitHub
   - Navigate to **Settings** → **Pages**
   - Under "Source", select **Deploy from a branch**
   - Select branch: **main** (or your default branch)
   - Select folder: **/docs**
   - Click **Save**

3. **Commit and push:**
   ```bash
   git add docs/
   git commit -m "Add WASM build for GitHub Pages"
   git push
   ```

4. **Access your app:**
   - Your app will be available at: `https://yourusername.github.io/backstorie/`
   - Wait a few minutes for deployment to complete

### .gitignore Configuration

Make sure your `.gitignore` allows the docs directory:

```gitignore
# Allow docs/ for GitHub Pages
!docs/
docs/*.wasm
docs/*.wasm.js
```

Or simply commit all files in docs/:
```bash
git add -f docs/
```

## Option 2: Root Directory Deployment

If you want to deploy from the root directory:

### Setup

1. **Compile to root:**
   ```bash
   ./compile_wasm.sh -o . -r
   ```

2. **Configure GitHub Pages:**
   - Go to **Settings** → **Pages**
   - Select folder: **/ (root)**

3. **Commit and push:**
   ```bash
   git add index.html backstorie.js backstorie.wasm.js backstorie.wasm
   git commit -m "Add WASM build for GitHub Pages"
   git push
   ```

**Note:** This approach clutters your root directory. Use Option 1 if possible.

## Option 3: gh-pages Branch

For a cleaner separation, use a dedicated branch:

### Setup

1. **Create gh-pages branch:**
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   ```

2. **Compile and commit:**
   ```bash
   git checkout main
   ./compile_wasm.sh -o /tmp/wasm-build -r
   
   git checkout gh-pages
   cp /tmp/wasm-build/* .
   git add .
   git commit -m "Deploy WASM build"
   git push origin gh-pages
   ```

3. **Configure GitHub Pages:**
   - Select branch: **gh-pages**
   - Select folder: **/ (root)**

### Automation Script

Create `deploy.sh` for easy deployment:

```bash
#!/bin/bash
# Deploy to gh-pages branch

echo "Building WASM..."
./compile_wasm.sh -o /tmp/backstorie-wasm -r

echo "Switching to gh-pages branch..."
git checkout gh-pages

echo "Copying files..."
cp /tmp/backstorie-wasm/* .

echo "Committing..."
git add .
git commit -m "Deploy $(date)"

echo "Pushing..."
git push origin gh-pages

echo "Switching back to main..."
git checkout main

echo "✓ Deployed to GitHub Pages!"
```

## Testing Locally

Before deploying, always test locally:

```bash
# Compile and serve
./compile_wasm.sh -o docs -r -s

# Or manually
cd docs
python3 -m http.server 8000
```

Then open http://localhost:8000

## Custom Domain

To use a custom domain:

1. **Add CNAME file:**
   ```bash
   echo "yourdomain.com" > docs/CNAME
   # or
   echo "yourdomain.com" > CNAME
   ```

2. **Configure DNS:**
   Add these DNS records at your domain provider:
   ```
   Type: A
   Name: @
   Value: 185.199.108.153
   
   Type: A
   Name: @
   Value: 185.199.109.153
   
   Type: A
   Name: @
   Value: 185.199.110.153
   
   Type: A
   Name: @
   Value: 185.199.111.153
   ```

3. **Update GitHub Pages settings:**
   - Enter your custom domain
   - Enable "Enforce HTTPS"

## Troubleshooting

### 404 Error

**Problem:** Page shows 404 after deployment

**Solutions:**
- Wait 5-10 minutes for GitHub Pages to build
- Check that `index.html` exists in the deployed directory
- Verify GitHub Pages is enabled in repository settings
- Check Actions tab for build errors

### Blank Screen

**Problem:** Page loads but shows blank screen

**Solutions:**
- Open browser console (F12) to check for errors
- Verify all files are present:
  - `index.html`
  - `backstorie.js`
  - `backstorie.wasm.js`
  - `backstorie.wasm`
- Check that WASM file is served with correct MIME type
- Try in a different browser

### WASM Loading Error

**Problem:** "Failed to load WASM module"

**Solutions:**
- Ensure files are served over HTTPS (GitHub Pages uses HTTPS by default)
- Check that `backstorie.wasm` file exists and is not corrupted
- Verify the file isn't blocked by browser extensions
- Check Network tab in browser DevTools for 404s

### Files Not Updating

**Problem:** Changes aren't reflected on the site

**Solutions:**
- Hard refresh the page (Ctrl+Shift+R or Cmd+Shift+R)
- Clear browser cache
- Wait for GitHub Pages to rebuild (can take a few minutes)
- Check the deployment timestamp in GitHub

## Example Workflows

### Simple Development Workflow

```bash
# 1. Develop locally
./compile.sh myapp

# 2. Test in browser
./compile_wasm.sh -o docs -r -s

# 3. Deploy
git add docs/
git commit -m "Update app"
git push
```

### Multi-Example Deployment

Deploy multiple examples to subdirectories:

```bash
# Compile different examples
./compile_wasm.sh -o docs/boxes -r example_boxes
./compile_wasm.sh -o docs/particles -r example_particles
./compile_wasm.sh -o docs/counter -r example_counter

# Create index page linking to examples
cat > docs/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Backstorie Examples</title></head>
<body>
  <h1>Backstorie Examples</h1>
  <ul>
    <li><a href="boxes/">Bouncing Boxes</a></li>
    <li><a href="particles/">Particle System</a></li>
    <li><a href="counter/">Frame Counter</a></li>
  </ul>
</body>
</html>
EOF

# Deploy
git add docs/
git commit -m "Add multiple examples"
git push
```

## Best Practices

1. **Always compile in release mode** for deployment: `-r`
2. **Test locally first** before pushing
3. **Use semantic versioning** in commit messages
4. **Keep docs/ in version control** for easy rollback
5. **Minimize file sizes** - WASM files can be large
6. **Add a README** in docs/ explaining what users will see
7. **Consider caching** - GitHub Pages has good CDN caching

## Summary

**Recommended approach for most projects:**

```bash
# One-time setup
./compile_wasm.sh -o docs -r

# Configure GitHub Pages to use /docs directory
# Commit and push

# Future updates
./compile_wasm.sh -o docs -r
git add docs/
git commit -m "Update"
git push
```

Your app will be live at: `https://yourusername.github.io/repositoryname/`

# n8n on Fly.io

> Deploy a production-ready [n8n](https://n8n.io) workflow automation instance on [Fly.io](https://fly.io) in minutes.

![n8n](https://img.shields.io/badge/n8n-latest-orange)
![Fly.io](https://img.shields.io/badge/Fly.io-ready-purple)
![License](https://img.shields.io/badge/license-MIT-blue)

## ✨ Features

- **One-command deployment** — Interactive setup handles everything
- **Persistent storage** — Your workflows survive restarts and redeployments
- **Auto-sleep** — Scales to zero when idle, saving costs
- **Python support** — Code nodes with Python environment included
- **Secure secrets** — URLs and credentials never stored in code

## 🚀 Quick Start

### Prerequisites

1. [Create a Fly.io account](https://fly.io/app/sign-up) (free tier available)
2. Install the Fly CLI:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```
3. Login to Fly:
   ```bash
   flyctl auth login
   ```

### Deploy

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/n8n-fly.git
cd n8n-fly

# Create your Fly app (choose a unique name)
flyctl apps create my-n8n-app

# Update fly.toml with your app name
sed -i '' "s/app = .*/app = 'my-n8n-app'/" fly.toml

# Deploy!
./deploy.sh
```

The deploy script will:
1. ✅ Check prerequisites
2. ✅ Prompt for your n8n URL
3. ✅ Create persistent storage
4. ✅ Deploy to Fly.io

## 📖 Usage

### Deploy Commands

```bash
./deploy.sh              # Full deployment
./deploy.sh setup        # Configure without deploying
./deploy.sh secrets      # Update URL configuration
./deploy.sh status       # Check app status
./deploy.sh logs         # Stream live logs
./deploy.sh ssh          # SSH into container
./deploy.sh help         # Show all commands
```

### Manual Commands

```bash
# View logs
flyctl logs -a my-n8n-app

# Check status
flyctl status -a my-n8n-app

# Restart the app
flyctl apps restart my-n8n-app

# Scale resources
flyctl scale memory 2048 -a my-n8n-app

# Open in browser
flyctl open -a my-n8n-app
```

## ⚙️ Configuration

### Environment Variables

Edit `fly.toml` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `GENERIC_TIMEZONE` | `Europe/Amsterdam` | Timezone for scheduled workflows |
| `EXECUTIONS_DATA_PRUNE` | `true` | Auto-delete old execution data |
| `EXECUTIONS_DATA_MAX_AGE` | `48` | Hours to keep execution data |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | `1000` | Max executions to retain |

### Resources

Default configuration in `fly.toml`:

```toml
[[vm]]
  cpu_kind = 'shared'
  cpus = 1
  memory_mb = 1024
```

For heavier workloads:

```bash
# Upgrade to 2GB RAM
flyctl scale memory 2048 -a my-n8n-app

# Use dedicated CPU
flyctl scale vm dedicated-cpu-1x -a my-n8n-app
```

### Custom Domain

```bash
# Add your domain
flyctl certs create n8n.yourdomain.com -a my-n8n-app

# Update DNS as instructed, then update n8n URLs
./deploy.sh secrets
# Enter: https://n8n.yourdomain.com
```

## 🔐 Security

### Secrets Management

Sensitive values are stored as Fly secrets, not in code:

```bash
# View current secrets (names only)
flyctl secrets list -a my-n8n-app

# Set additional secrets
flyctl secrets set MY_API_KEY="xxx" -a my-n8n-app
```

### Recommended: Enable n8n Authentication

After first deployment, set up authentication in n8n:

1. Go to **Settings** → **Users**
2. Create an owner account
3. Or set via environment:
   ```bash
   flyctl secrets set \
     N8N_BASIC_AUTH_ACTIVE=true \
     N8N_BASIC_AUTH_USER=admin \
     N8N_BASIC_AUTH_PASSWORD=your-secure-password \
     -a my-n8n-app
   ```

## 💰 Cost Estimate

With default settings and auto-sleep enabled:

| Usage | Estimated Cost |
|-------|---------------|
| Light (few hours/day) | ~$0-2/month |
| Moderate (8 hours/day) | ~$3-5/month |
| Always-on | ~$5-7/month |

> Fly.io's free tier includes enough resources for light usage.

## 🔧 Troubleshooting

### App won't start

```bash
# Check logs for errors
flyctl logs -a my-n8n-app

# Verify volume exists
flyctl volumes list -a my-n8n-app

# Check machine status
flyctl machines list -a my-n8n-app
```

### Volume issues

```bash
# If volume is in wrong region, create new one
flyctl volumes create n8n_vol --size 1 --region ams -a my-n8n-app
```

### Reset everything

```bash
# Destroy and recreate (⚠️ loses all data)
flyctl apps destroy my-n8n-app
flyctl apps create my-n8n-app
flyctl volumes create n8n_vol --size 1 --region ams -a my-n8n-app
./deploy.sh
```

## 📁 Project Structure

```
n8n-fly/
├── deploy.sh              # Deployment script
├── fly.toml               # Fly.io configuration
├── Dockerfile             # Container definition
├── docker-entrypoint.sh   # Startup script
├── requirements.txt       # Python dependencies
├── n8n-task-runners.json  # Task runner config
└── README.md
```

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - feel free to use this for your own projects.

## 🙏 Acknowledgments

- [n8n](https://n8n.io) — Fair-code workflow automation
- [Fly.io](https://fly.io) — Deploy app servers close to your users

[![Docker Pulls](https://img.shields.io/docker/pulls/mitexleo/openvas.svg)](https://hub.docker.com/r/mitexleo/openvas/)
[![Docker Stars](https://img.shields.io/docker/stars/mitexleo/openvas?style=flat)](https://hub.docker.com/r/mitexleo/openvas/)
[![Docker Image Size](https://img.shields.io/docker/image-size/mitexleo/openvas.svg?maxAge=2592000)](https://hub.docker.com/r/mitexleo/openvas/)
[![GitHub Issues](https://img.shields.io/github/issues-raw/sysplore/openvas-docker.svg)](https://github.com/sysplore/openvas-docker/issues)
[![Discord](https://img.shields.io/discord/809911669634498596?label=Discord&logo=discord)](https://discord.gg/DtGpGFf7zV)
[![Twitter Badge](https://badgen.net/badge/icon/twitter?icon=twitter&label)](https://twitter.com/mitexleo)
![GitHub Repo stars](https://img.shields.io/github/stars/sysplore/openvas-docker?style=social)

![Sysplore](branding/Sysplore.png)

# 🐳 OpenVAS Docker - Greenbone Vulnerability Management Container

> **Enterprise-grade vulnerability scanning made easy with Docker**

## ✨ Features

- **Latest Greenbone Components** - Always up-to-date with the latest vulnerability feeds
- **Multi-architecture Support** - Runs on `amd64` and `arm64` (Apple Silicon & Raspberry Pi)
- **Pre-configured & Ready-to-Run** - No complex setup required
- **Single & Multi-container Deployments** - Flexible deployment options
- **Automatic Feed Updates** - Built-in synchronization with Greenbone vulnerability feeds
- **PostgreSQL 15** - Modern database backend with improved performance

## 🚀 Quick Start

### Single Container Deployment (Simplest)

```bash
docker run -d \
  --name openvas \
  -p 8080:9392 \
  -e SKIPSYNC=true \
  mitexleo/openvas:latest
```

Access the web interface at: [http://localhost:8080](http://localhost:8080)

**Default Credentials:**
- **Username:** `admin`
- **Password:** `admin`

> ⚠️ **Note:** Set `SKIPSYNC=false` (or remove the environment variable) to download vulnerability feeds (2-3GB). This can take several hours on first run.

### Docker Compose Deployment

```yaml
version: '3.8'
services:
  openvas:
    image: mitexleo/openvas:latest
    container_name: openvas
    ports:
      - "8080:9392"
    environment:
      - SKIPSYNC=true
    volumes:
      - openvas_data:/data
      - openvas_logs:/var/log/gvm

volumes:
  openvas_data:
  openvas_logs:
```

## 📦 Docker Tags

| Tag | Description | Architecture |
|-----|-------------|--------------|
| `25.12.26.02` | Latest based on GVMd 24 | `amd64`, `arm64` |
| `21.04.09` | Last 21.4 build | `amd64`, `arm64` |
| `20.08.04.6` | Last 20.08 image | `amd64`, `arm64` |
| `pre-20.08` | Last image from before the 20.08 update | `amd64` |
| `v1.0` | Historical reference (not recommended) | `amd64` |

## 🔧 Greenbone Component Versions (Latest Image)

| Component | Version | Component | Version |
|-----------|---------|-----------|---------|
| **gvmd** | v26.25.0 | **gvm_libs** | v23.6.0 |
| **openvas** | v23.47.2 | **openvas_smb** | v22.5.10 |
| **notus_scanner** | v22.7.2 | **gsa** | v27.4.1 |
| **gsad** | v26.4.0 | **ospd** | v21.4.4 |
| **ospd_openvas** | v22.10.1 | **pg_gvm** | v22.6.17 |
| **python_gvm** | v27.4.0 | **gvm_tools** | v26.0.6 |
| **greenbone_feed_sync** | v25.3.0 | | |

## 📚 Documentation

### Container Documentation
- [Project Documentation](https://sysplore.github.io/openvas-docker/)
- [GitHub Repository](https://github.com/sysplore/openvas-docker)
- [Issue Tracker](https://github.com/sysplore/openvas-docker/issues)

### Greenbone Vulnerability Manager Documentation
- [Official Greenbone Documentation](https://docs.greenbone.net/GSM-Manual/gos-22.04/en/)
- **Chapters 8-14** cover scanning configuration and usage

## 🛠️ Advanced Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIPSYNC` | `false` | Set to `true` to skip initial feed synchronization |
| `PGVER` | `15` | PostgreSQL version (only 15 supported) |
| `LISTEN_ADDRESS` | `0.0.0.0` | GSAD listening address |
| `PORT` | `9392` | GSAD listening port |

### Persistent Volumes

For production deployments, mount these volumes:

```bash
docker run -d \
  -v openvas_data:/data \
  -v openvas_logs:/var/log/gvm \
  -v openvas_redis:/var/lib/redis \
  mitexleo/openvas:latest
```

## 🔄 Updating Feeds

To manually update vulnerability feeds:

```bash
docker exec openvas greenbone-feed-sync
```

Or run the container in refresh mode:

```bash
docker run --rm mitexleo/openvas:latest refresh
```

## 🏗️ Building from Source

```bash
# Clone the repository
git clone https://github.com/sysplore/openvas-docker.git
cd openvas-docker

# Build the image
./bin/base-rebuild.sh
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](https://github.com/sysplore/openvas-docker/blob/main/CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## 🆘 Support

- **GitHub Issues:** [Report Bugs & Features](https://github.com/sysplore/openvas-docker/issues)
- **Discord:** [Join our Community](https://discord.gg/DtGpGFf7zV)
- **Documentation:** [Check the Docs First](https://sysplore.github.io/openvas-docker/)

## ☕ Support the Project

This project is maintained by **Sysplore** with help from the open-source community.

If you find this project useful, please consider supporting its development:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://bmc.link/mitexleo)  
[![Patreon](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://patreon.com/mitexleo)

## 📄 License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

OpenVAS and Greenbone Vulnerability Manager are trademarks of Greenbone Networks AG.

---

**Maintained with ❤️ by [Sysplore](https://github.com/sysplore) | 🐛 [Report Issue](https://github.com/sysplore/openvas-docker/issues) | 📖 [Documentation](https://sysplore.github.io/openvas-docker/)**
# Remote Upload Action

A GitHub Action for securely uploading files to a remote server via SSH/SCP or rsync.

## Features

- Secure file uploads using SSH key authentication
- Support for both SCP and rsync (with automatic fallback)
- Optional post-upload command execution on the remote server
- Detailed transfer statistics as outputs
- Customizable port and transfer options

## Usage

```yaml
- name: Upload to remote server
  uses: melmass/actions@remote-upload
  with:
    host: 'your-server.example.com'
    username: 'your-username'
    private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    source: './dist/'
    destination: '/var/www/html/'
    # Optional parameters
    port: '22'
    rsync: 'true'
    options: '--exclude=.git --delete'
    post-commands: 'chmod -R 755 /var/www/html; systemctl restart nginx'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `host` | Remote server hostname or IP address | Yes | |
| `username` | SSH username | Yes | |
| `private-key` | SSH private key for authentication (use GitHub secrets) | Yes | |
| `source` | Source path (local files to upload) | Yes | |
| `destination` | Destination path on the remote server | Yes | |
| `port` | SSH port number | No | `22` |
| `rsync` | Use rsync instead of scp (more efficient for large transfers) | No | `true` |
| `options` | Additional options for rsync/scp | No | |
| `post-commands` | Commands to execute on the remote server after upload (semicolon-separated) | No | |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | Upload status (success/failure) |
| `transferred-files` | Number of files transferred |
| `transferred-bytes` | Number of bytes transferred |

## Examples

### Basic Upload

```yaml
- name: Upload website files
  uses: melmass/actions@remote-upload
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    source: './build/'
    destination: '/var/www/mysite/'
```

### Using SCP with Custom Port

```yaml
- name: Upload with SCP
  uses: melmass/actions@remote-upload
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    port: '2222'
    rsync: 'false'
    source: './dist/'
    destination: '/var/www/html/'
```

### With Post-Upload Commands

```yaml
- name: Upload and restart services
  uses: melmass/actions@remote-upload
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    source: './dist/'
    destination: '/var/www/html/'
    post-commands: 'chmod -R 755 /var/www/html; systemctl restart nginx; echo "Deployment completed at $(date)"'
```

## Security Notes

- Always store your SSH private key as a GitHub secret
- Consider using a dedicated deployment user with limited permissions on your server
- For added security, you can restrict the SSH key to only allow file transfers

## License

MIT

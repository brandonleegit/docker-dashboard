#!/bin/bash

# Read Docker hosts from the environment variable
IFS=',' read -ra DOCKER_HOSTS <<< "$DOCKER_HOSTS"
SSH_KEY="~/.ssh/id_rsa" # Path to your SSH private key
OUTPUT_FILE="/var/www/html/docker_containers.html"
TEMP_FILE="/tmp/docker_containers_temp.html"

# Initialize counters
TOTAL_HOSTS=0
TOTAL_CONTAINERS=0

# Get the snapshot time
SNAPSHOT_TIME=$(date +"%A, %B %d, %Y %H:%M:%S")

# Initialize HTML file
cat > "$TEMP_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Docker Containers Dashboard</title>
    <style>
        :root {
            --bg-color: #121212;
            --text-color: #ffffff;
            --table-bg-color: #1e1e1e;
            --table-border-color: #333;
            --input-bg-color: #333;
            --input-border-color: #555;
            --log-text-color: #000000;
        }

        [data-theme="light"] {
            --bg-color: #ffffff;
            --text-color: #000000;
            --table-bg-color: #f2f2f2;
            --table-border-color: #ddd;
            --input-bg-color: #ffffff;
            --input-border-color: #ddd;
            --log-text-color: #000000;
        }

        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: var(--bg-color);
            color: var(--text-color);
        }

        table {
            border-collapse: collapse;
            width: 100%;
            table-layout: fixed;
        }

        th, td {
            border: 1px solid var(--table-border-color);
            padding: 8px;
            text-align: left;
            word-wrap: break-word;
            white-space: pre-wrap;
        }

        th {
            background-color: var(--table-bg-color);
            cursor: pointer;
            position: relative;
        }

        th.sorted-asc::after {
            content: "▲";
            font-size: 12px;
            margin-left: 8px;
            color: var(--text-color);
        }

        th.sorted-desc::after {
            content: "▼";
            font-size: 12px;
            margin-left: 8px;
            color: var(--text-color);
        }

        #searchInput {
            margin-bottom: 10px;
            padding: 8px;
            width: 100%;
            border: 1px solid var(--input-border-color);
            background-color: var(--input-bg-color);
            color: var(--text-color);
        }

        #darkModeToggle {
            margin-bottom: 10px;
            padding: 8px;
            cursor: pointer;
            background-color: var(--table-bg-color);
            border: 1px solid var(--table-border-color);
            color: var(--text-color);
        }

        .log-toggle {
            cursor: pointer;
            color: var(--log-text-color);
        }

        .logs {
            display: none;
            white-space: pre-wrap;
            margin-top: 5px;
            padding: 8px;
            background-color: var(--table-bg-color);
            border: 1px solid var(--table-border-color);
        }
    </style>
</head>
<body data-theme="dark">
    <h1>Docker Containers Dashboard</h1>
    <div class="summary" id="summary">
        <p>
            <span>Total Docker Hosts: <span id="totalHosts">0</span></span>, 
            <span>Total Containers: <span id="totalContainers">0</span></span>
        </p>
        <p>Snapshot Time: <span id="snapshotTime">${SNAPSHOT_TIME}</span></p>
    </div>
    <button id="darkModeToggle">Toggle Light Mode</button>
    <input type="text" id="searchInput" placeholder="Search for Docker Host, Container, Image, or Ports..." />
    <table id="dockerTable">
        <thead>
            <tr>
                <th class="sortable">Docker Host</th>
                <th class="sortable">Host IP</th>
                <th class="sortable">Container Name</th>
                <th class="sortable">Image</th>
                <th class="sortable">Tag</th>
                <th class="sortable">Exposed Ports</th>
                <th class="sortable">Internal IP</th>
                <th class="sortable">Networks</th>
                <th class="sortable">Restart Count</th>
                <th class="sortable">Volumes</th>
                <th class="sortable">Uptime</th>
            </tr>
        </thead>
        <tbody>
EOF

# Loop through Docker hosts and gather information
for HOST in "${DOCKER_HOSTS[@]}"; do
    echo "Connecting to $HOST..."

    SSH_CMD="ssh -o StrictHostKeyChecking=no -i $SSH_KEY $HOST"
    HOST_IP=$($SSH_CMD "hostname -I" 2>/dev/null | awk '{print $1}')
    CONTAINER_IDS=$($SSH_CMD "docker ps -q" 2>/dev/null)

    if [[ $? -ne 0 || -z "$CONTAINER_IDS" ]]; then
        HOSTNAME=$(echo "$HOST" | awk -F@ '{print $2}')
        echo "<tr><td colspan='11'>Failed to connect to $HOSTNAME or no containers running</td></tr>" >> "$TEMP_FILE"
        continue
    fi

    HOSTNAME=$(echo "$HOST" | awk -F@ '{print $2}')
    CONTAINER_COUNT=0

    for CONTAINER_ID in $CONTAINER_IDS; do
        CONTAINER_NAME=$($SSH_CMD "docker inspect --format='{{.Name}}' $CONTAINER_ID" | sed 's|/||')
        IMAGE=$($SSH_CMD "docker inspect --format='{{.Config.Image}}' $CONTAINER_ID")
        TAG=$(echo "$IMAGE" | awk -F: '{print $2}')
        PORTS=$($SSH_CMD "docker port $CONTAINER_ID" | tr '\n' ' ')
        INTERNAL_IP=$($SSH_CMD "docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_ID")
        START_TIME=$($SSH_CMD "docker inspect --format='{{.State.StartedAt}}' $CONTAINER_ID")
        START_TIMESTAMP=$(date -d "$(echo $START_TIME | sed 's/\.[0-9]*Z//' | sed 's/T/ /')" +%s 2>/dev/null || echo "Invalid date")

        if [[ $START_TIMESTAMP != "Invalid date" ]]; then
            UPTIME=$(echo $(( $(date +%s) - START_TIMESTAMP )) | awk '{printf "%d days, %02d:%02d:%02d\n", int($1/86400), int($1%86400/3600), int($1%3600/60), $1%60}')
        else
            UPTIME="Invalid date"
        fi

        NETWORKS=$($SSH_CMD "docker inspect --format='{{range \$key, \$value := .NetworkSettings.Networks}}{{\$key}},{{end}}' $CONTAINER_ID" | sed 's/,$//')
        RESTART_COUNT=$($SSH_CMD "docker inspect --format='{{.RestartCount}}' $CONTAINER_ID")
        VOLUMES=$($SSH_CMD "docker inspect --format='{{range .Mounts}}{{.Source}},{{end}}' $CONTAINER_ID" | sed 's/,$//')
        LOGS=$($SSH_CMD "docker logs --tail=10 $CONTAINER_ID" 2>/dev/null)

        echo "<tr>
            <td>${HOSTNAME}</td>
            <td>${HOST_IP:-N/A}</td>
            <td>${CONTAINER_NAME} <button class='log-toggle' onclick='toggleLogs(\"log-${CONTAINER_ID}\")'>Logs</button>
                <div id='log-${CONTAINER_ID}' class='logs'>${LOGS:-No logs available}</div>
            </td>
            <td>${IMAGE}</td>
            <td>${TAG:-latest}</td>
            <td>${PORTS:-None}</td>
            <td>${INTERNAL_IP:-N/A}</td>
            <td>${NETWORKS:-N/A}</td>
            <td>${RESTART_COUNT:-0}</td>
            <td>${VOLUMES:-None}</td>
            <td>${UPTIME}</td>
        </tr>" >> "$TEMP_FILE"

        CONTAINER_COUNT=$((CONTAINER_COUNT + 1))
    done

    TOTAL_HOSTS=$((TOTAL_HOSTS + 1))
    TOTAL_CONTAINERS=$((TOTAL_CONTAINERS + CONTAINER_COUNT))
done

# Close HTML file with JavaScript
cat >> "$TEMP_FILE" <<EOF
        </tbody>
    </table>
    <script>
        document.getElementById('totalHosts').textContent = "${TOTAL_HOSTS}";
        document.getElementById('totalContainers').textContent = "${TOTAL_CONTAINERS}";

        function toggleLogs(logId) {
            const logElement = document.getElementById(logId);
            logElement.style.display = logElement.style.display === 'block' ? 'none' : 'block';
        }

        const darkModeToggle = document.getElementById('darkModeToggle');
        darkModeToggle.addEventListener('click', () => {
            const currentTheme = document.body.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            document.body.setAttribute('data-theme', newTheme);
            darkModeToggle.textContent = newTheme === 'dark' ? 'Toggle Light Mode' : 'Toggle Dark Mode';
        });

        document.querySelectorAll('.sortable').forEach(header => {
            header.addEventListener('click', () => {
                const table = header.closest('table');
                const rows = Array.from(table.querySelector('tbody').rows);
                const index = Array.from(header.parentNode.children).indexOf(header);
                const ascending = !header.classList.contains('sorted-asc');
                rows.sort((a, b) => {
                    const aText = a.cells[index].textContent.trim();
                    const bText = b.cells[index].textContent.trim();
                    return ascending
                        ? aText.localeCompare(bText, undefined, { numeric: true })
                        : bText.localeCompare(aText, undefined, { numeric: true });
                });
                rows.forEach(row => table.querySelector('tbody').appendChild(row));
                header.classList.toggle('sorted-asc', ascending);
                header.classList.toggle('sorted-desc', !ascending);
                table.querySelectorAll('.sortable').forEach(th => th !== header && th.classList.remove('sorted-asc', 'sorted-desc'));
            });
        });

        document.getElementById('searchInput').addEventListener('input', function() {
            const filter = this.value.toLowerCase();
            const rows = document.querySelectorAll('#dockerTable tbody tr');
            rows.forEach(row => {
                const containerLogs = row.querySelector(".logs");
                if (containerLogs) containerLogs.style.display = "none";
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(filter) ? '' : 'none';
            });
        });
    </script>
</body>
</html>
EOF

# Replace the live file only after generation is complete
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Docker containers dashboard generated: $OUTPUT_FILE"

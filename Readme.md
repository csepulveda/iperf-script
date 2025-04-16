# Kubernetes iperf3 Node-to-Node Network Test Script

This script simplifies running an `iperf3` network bandwidth test between two Kubernetes nodes using `networkstatic/iperf3`.

It deploys:
- An **iperf3 server** pod pinned to a specified node.
- An **iperf3 client** job pinned to another node.
- Optionally uses a **Kubernetes Service** (ClusterIP or NodePort) to connect the client to the server via DNS.

All resources are cleaned up automatically after the test.

---

## Usage

```bash
./iperf-nodes.sh <server-node-name> <client-node-name> [--use-service=ClusterIP|NodePort]
```

### Arguments

- `server-node-name`: The Kubernetes node to run the iperf3 server.
- `client-node-name`: The Kubernetes node to run the iperf3 client.
- `--use-service=...` *(optional)*:
  - If provided, creates a Kubernetes `Service` to expose the server.
  - Valid values: `ClusterIP` (default) or `NodePort`.

---

## Example Output
Using service:
```bash
./iperf-nodes.sh node01 mode02 --use-service=NodePort 
Creating namespace 'iperf-test' (if not exists)...
namespace/iperf-test configured
Deploying iperf3 server on node node01...
deployment.apps/iperf3-server created
Creating NodePort service to expose iperf3 server...
service/iperf3-service created
Waiting for iperf3 server pod to be ready...
pod/iperf3-server-75649476-q9d7f condition met
Using service address: iperf3-service.iperf-test.svc.cluster.local
Launching iperf3 client job from node mode02...
job.batch/iperf3-client created
Waiting for client job to complete...
job.batch/iperf3-client condition met
Client job completed. Fetching logs:
Connecting to host iperf3-service.iperf-test.svc.cluster.local, port 5201
[  5] local 10.0.1.23 port 37998 connected to 10.43.200.102 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   111 MBytes   928 Mbits/sec    0    511 KBytes       
[  5]   1.00-2.00   sec   109 MBytes   912 Mbits/sec    0    534 KBytes       
[  5]   2.00-3.00   sec   109 MBytes   912 Mbits/sec    0    534 KBytes       
[  5]   3.00-4.00   sec   108 MBytes   902 Mbits/sec    0    534 KBytes       
[  5]   4.00-5.00   sec   109 MBytes   913 Mbits/sec    0    534 KBytes       
[  5]   5.00-6.00   sec   108 MBytes   904 Mbits/sec    0    534 KBytes       
[  5]   6.00-7.00   sec   109 MBytes   910 Mbits/sec    0    534 KBytes       
[  5]   7.00-8.00   sec   110 MBytes   919 Mbits/sec    0    642 KBytes       
[  5]   8.00-9.00   sec   108 MBytes   902 Mbits/sec    0    642 KBytes       
[  5]   9.00-10.00  sec   109 MBytes   912 Mbits/sec    0    642 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.06 GBytes   911 Mbits/sec    0             sender
[  5]   0.00-10.00  sec  1.06 GBytes   909 Mbits/sec                  receiver

iperf Done.
Cleaning up resources...
job.batch "iperf3-client" deleted
deployment.apps "iperf3-server" deleted
service "iperf3-service" deleted
```

pod to pod:
```bash
Creating namespace 'iperf-test' (if not exists)...
namespace/iperf-test configured
Deploying iperf3 server on node node01...
deployment.apps/iperf3-server created
Waiting for iperf3 server pod to be ready...
pod/iperf3-server-75649476-vxcf6 condition met
Using pod IP address: 10.0.0.158
Launching iperf3 client job from node mode02...
job.batch/iperf3-client created
Waiting for client job to complete...
job.batch/iperf3-client condition met
Client job completed. Fetching logs:
Connecting to host 10.0.0.158, port 5201
[  5] local 10.0.1.73 port 53964 connected to 10.0.0.158 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   110 MBytes   924 Mbits/sec    0    471 KBytes       
[  5]   1.00-2.00   sec   109 MBytes   917 Mbits/sec    0    583 KBytes       
[  5]   2.00-3.00   sec   109 MBytes   912 Mbits/sec    0    583 KBytes       
[  5]   3.00-4.00   sec   108 MBytes   902 Mbits/sec    0    583 KBytes       
[  5]   4.00-5.00   sec   108 MBytes   910 Mbits/sec    0    583 KBytes       
[  5]   5.00-6.00   sec   109 MBytes   910 Mbits/sec    0    583 KBytes       
[  5]   6.00-7.00   sec   108 MBytes   908 Mbits/sec    0    613 KBytes       
[  5]   7.00-8.00   sec   108 MBytes   906 Mbits/sec    0    613 KBytes       
[  5]   8.00-9.00   sec   109 MBytes   917 Mbits/sec    0    613 KBytes       
[  5]   9.00-10.00  sec   108 MBytes   906 Mbits/sec    0    613 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.06 GBytes   911 Mbits/sec    0             sender
[  5]   0.00-10.00  sec  1.06 GBytes   908 Mbits/sec                  receiver

iperf Done.
Cleaning up resources...
job.batch "iperf3-client" deleted
deployment.apps "iperf3-server" deleted
```

---

## 🧹 Automatic Cleanup

The script uses `trap` to automatically delete:

- The iperf3 client `Job`
- The iperf3 server `Deployment`
- The optional `Service`

Optionally, you can uncomment a line in the script to remove the namespace as well.

---

## 🔧 Requirements

- A working Kubernetes cluster with:
  - Nodes labeled with `kubernetes.io/hostname`
  - `kubectl` configured and authenticated
- Bash
- Access to `networkstatic/iperf3` image

---

## 📝 License

MIT – free to use, modify, and contribute.

---

## 👨‍💻 Author

Built by [@csepulveda](https://github.com/csepulveda) — contributions welcome!
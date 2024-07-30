# How to access a Granica Dashboard from Pinterest laptop

1. Put public part of your SSH key on the Admin Server EC2 instance (run on Pinterest laptop)

```bash
aws ec2-instance-connect ssh --instance-id i-1234567890 --connection-type eice --region us-east-1
```

```
cat ~/.ssh/your-key.pub
```

Copy the contents and place them on the EC2 Instance in `~/.ssh/authorized_keys`

2. Create a tunnel via AWS EC2 Instance Connect (run on Pinterest laptop)

```bash
aws ec2-instance-connect open-tunnel --instance-id i-1234567890 --local-port 8888 --region us-east-1
```

You can now SSH into the Admin Server like `ssh -i ~/.ssh/your-key ec2-user@localhost -p 8888`

3. Create SSH port-forwarding (run on Pinterest laptop)

```bash
ssh -i ~/.ssh/your-key -fN ec2-user@localhost -p 8888 -L 6443:localhost:6443
```

To stop this, run `ps aux | grep ssh` and kill the process associated with the above command.

4. Port-forward the Granica Dashboard (ron on Admin Server)

SSH onto the Admin Server in whatever way and run the following command

```bash
kubectl port-forward service/dashboard 6443:3000
```

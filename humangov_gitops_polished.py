from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EKS, ECR
from diagrams.aws.network import Route53, ALB, VPC
from diagrams.aws.database import Dynamodb
from diagrams.aws.storage import S3
from diagrams.aws.devtools import Codebuild, Codepipeline
from diagrams.onprem.vcs import Github
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.k8s.compute import Pod, ReplicaSet
from diagrams.onprem.client import User, Users

# --- STYLING ---
# "splines": "ortho" makes lines straight (90 degree angles) like a blueprint
# "nodesep": increases space between icons
graph_attr = {
    "splines": "ortho",
    "fontsize": "14",
    "nodesep": "0.60",
    "ranksep": "0.75",
    "bgcolor": "white"
}

with Diagram("HumanGov GitOps Architecture (Professional)", show=False, direction="LR", graph_attr=graph_attr):

    # --- 1. THE SOURCE & BUILD LANE (Top) ---
    with Cluster("Development & CI Flow"):
        dev = User("Developer")
        git = Github("GitHub Repo\n(Code + Manifests)")
        
        with Cluster("AWS CI Pipeline"):
            ci_trigger = Codepipeline("Trigger")
            builder = Codebuild("CodeBuild\n(Build & Write-Back)")
            ecr = ECR("Private ECR")

    # --- 2. THE INFRASTRUCTURE (Main Box) ---
    with Cluster("AWS Cloud (us-east-1)"):
        
        with Cluster("VPC (Zero Trust Network)"):
            
            # --- TRAFFIC ENTRY ---
            with Cluster("Public Ingress"):
                r53 = Route53("Route 53")
                alb = ALB("AWS ALB")

            # --- KUBERNETES CLUSTER ---
            with Cluster("EKS Cluster (humangov-cluster)"):
                
                # GitOps Engine
                with Cluster("GitOps Controller"):
                    argo = Argocd("ArgoCD")

                # Platform Tools (Monitoring/Scaling)
                with Cluster("Observability & Scaling"):
                    prom = Prometheus("Prometheus")
                    graf = Grafana("Grafana")
                    keda = Pod("KEDA\nOperator")

                # The Application (Workload)
                with Cluster("Namespace: humangov-prod"):
                    nginx = Pod("Nginx Proxy")
                    app = Pod("Python App")
                    scaler = ReplicaSet("Auto-Scaling")

            # --- DATA STORAGE ---
            with Cluster("Data Persistence"):
                db = Dynamodb("DynamoDB")
                s3 = S3("S3 Bucket")

    # --- 3. EXTERNAL USERS (Left) ---
    with Cluster("Access"):
        end_users = Users("Public Users")

    # ==========================================
    #          WIRING THE CONNECTIONS
    # ==========================================

    # 1. User Traffic Flow (Straight Line)
    end_users >> Edge(label="HTTPS", color="black") >> r53
    r53 >> Edge(color="black") >> alb
    alb >> Edge(color="black") >> nginx
    nginx >> app

    # 2. Developer & CI Flow (Top Line)
    dev >> git
    git >> ci_trigger >> builder
    builder >> Edge(label="Push Image") >> ecr
    # The Write-Back Loop
    builder >> Edge(label="Update Manifest", style="dashed", color="blue") >> git

    # 3. GitOps Sync Flow
    # Argo pulls from Git and deploys to App
    git << Edge(label="Syncs Config", color="green", style="bold") << argo
    argo >> Edge(color="green") >> app

    # 4. App Logic
    app >> db
    app >> s3

    # 5. Monitoring & Scaling Logic
    prom >> Edge(style="dotted") >> app
    graf >> Edge(style="dotted") >> prom
    keda >> Edge(style="dotted", label="Metrics") >> prom
    keda >> Edge(label="Scale") >> scaler
    scaler >> app
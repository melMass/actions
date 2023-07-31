import os
for env in os.environ:
    print(f"{env} : {os.environ[env]}")

print("----------")
print(sys.argv)
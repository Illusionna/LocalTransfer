'''
# System --> Windows & Python3.10.0
# File ----> resources.py
# Author --> Illusionna
# Create --> 2024/05/10 21:25:32
'''
# -*- Encoding: UTF-8 -*-


def Generate() -> None:
    """
    生成资源文件.
    """
    with open('./resources.zip', mode='rb') as f:
        data = f.read()

    with open('./utils/data.py', mode='w') as f:
        f.write(f"""'''
# System --> Windows & Python3.10.0
# File ----> data.py
# Author --> Illusionna
# Create --> 2024/05/10 21:39:47
'''
# -*- Encoding: UTF-8 -*-


binary = '{data.hex()}'""")


# Generate()
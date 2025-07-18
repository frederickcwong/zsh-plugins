## Steps

1. Make sure AWS CLI and pulumi are installed

2. Create AWS SSO Profile using the aws sso command for each environment (e.g. sandbox, production, test, etc.)
    
    `aws configure sso`

   A `config` file should be created in `${HOME}/.aws/config` and it should contains a profile you named using the configure command above. The `config` file should start with the line:

   `[profile oc-sandbox]`

   if you named the profile as `oc-sandbox`

3. Edit `${HOME}/.zshrc` and add this to the end of the file:

   `source ${PATH_TO_THE_SCRIPT}/awslogin/aws-login.plugin.zsh`

4. Edit the environment variables in:

   `${PATH_TO_THE_SCRIPT}/awslogin/awslogicrc.d/<profile name>.env`

   If the environment variable list contains `PULUMI_BACKEND_URL`, the script will automatically execute `pulumi login` command.

5. Launch a new terminal and type the following to test it out.

   `awslogin <profile>`
   
6. Repeat the process above for other aws profiles.

Note: 
- to logout from aws sso: `aws sso logout`
- to logut from pulumi: `pulumi logout`

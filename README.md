[![GitHub last commit](https://img.shields.io/github/last-commit/smbcheeky/update-env)](https://github.com/smbcheeky/update-env)
[![GitHub stars](https://img.shields.io/github/stars/smbcheeky/update-env)](https://img.shields.io/github/stars/smbcheeky/update-env)

## Description

This script was initially created to manage the environment configuration and secrets of any file-based project.

It allows the developer to exclude sensitive files from git version control and help keep every environment folder
organized with relative paths, similar to the root project.

The script conditionally includes special treatment for development with React Native and Expo, but can be easily
adjusted to ignore this part.

## Expo, React Native, EAS Build and .easignore

The EAS Build process uses the contents of .gitignore file to determine which files to include in the created JS bundle.
If however the files are excluded from git version control, they are not included in the bundle unless they are
explicitly included via the .easignore file.

If Expo is detected, the .easignore file will be automatically updated and the environment files entries will be
included in the EAS Build process and still kept outside git version control.

## How does it work?

```bash
chmod +x ./update-env.sh
./update-env.sh production
```

1. Copy the `update-env.sh` script to the root of the project
2. The script checks for the existence of the `.environment` folder in the root of the project
3. If the `.environment` folder exists, it checks for the existence of the `production` subfolder
4. It makes sure all files that need to be included in git version control are included, and all files that are not, are
   excluded.
5. It overrides the project files with the ones found in the `production` subfolder
6. To make sure everything is copied correctly, the `production` subfolder needs uses the same folder structure as the
   root project directory.
7. Once copied, the .gitignore file is updated to include the new entries
8. .gitignore changes that are managed by the script are organized neatly in a special section inside the .gitignore
   file
9. If Expo app.json, app.config.js or app.config.ts files are found, the .easignore file is also created and updated
   based on the .gitignore file with "a twist"
10. The environment files that are ignored in the .gitignore file are now included in the .easignore file.
11. .gitignore and .easignore existing entries are kept unchanged
12. The `update-env.lock` file is created to keep track of the changes made by the script and to make sure when changes
    are made, it is visible in git version control
13. If you want to add more files to the .gitignore file, but have them managed by the script, you can add them to
    the `update-env.ignore` file

## Setup example

- This setup is meant for two environments, `production` and `staging`
- Add the `use-production` and `use-staging` scripts to your `package.json` file
- Create a `.environment` folder in the root of your project
- Create a `production` folder in the `.environment` folder
- Add production files to the `production` folder while respecting the same relative path structure as the root project
- Run `./update-env.sh production` to update the project
- Create a `staging` folder in the `.environment` folder
- Add staging files to the `staging` folder while respecting the same relative path structure as the root project
- Run `./update-env.sh staging` to update the project

## Other notes

- The script can work with only one environment
- The `.ignored` folder is meant to be used as is and is useful for case where you need to use a secret/certificate, but
  it is not linked to the project files
- If you want to include a file in multiple environments, use copy and paste to add it manually to each one :) Trust me,
  it's better this way.
- Environments are determined by the subfolders present in the `.environment` folder
- An example archive of the `.environment` folder was committed along with the script
- There are 2 environments added, `production` and `staging` + a generic `.ignored` folder
- The `update-env.ignore` file is currently populated with entries used in Expo React Native projects
- The `update-env.lock` file is updated during the script execution, and used similar to a log file
- The `#.gitignore file placeholder` and `#.easignore file placeholder` are simple lines added to take place of existing
  lines in both files - they are used simply as part of the example and can be deleted
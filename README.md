# Appcircle Testing Distribution

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appcircle_testing_distribution)

Appcircle simplifies the distribution of builds to test teams with an extensive platform for managing and tracking applications, versions, testers, and teams. Appcircle integrates with enterprise authentication mechanisms such as LDAP and SSO, ensuring secure distribution of testing packages. Learn more about Appcircle testing distribution. Learn more about [Appcircle testing distribution](https://appcircle.io/testing-distribution?utm_source=fastlane&utm_medium=plugin&utm_campaign=testing_distribution)

Appcircle's test distribution extension enables developers to create test groups and share builds with them, utilizing enterprise-grade authentication methods. With the Fastlane plugin, this module will be accessible directly fastlane actions.

## Exploring Testing Distribution

Testing distribution is the process of distributing test builds to designated test groups or individuals. This process allows developers to gather quick feedback, identify bugs, and ensure the quality of software applications before releasing them to customers. Appcircle's test distribution module enables developers to create test groups and share builds with them, utilizing enterprise-grade authentication methods.

## Benefits of Using Testing Distribution

1. **Simplified Binary Distribution**.
   - **Skip Traditional Stores:** Share .xcarchive .IPA, APK, AAB, Zip, files directly, avoiding the need to use App Store TestFlight or Google Play Internal Testing.
2. **Streamlined Workflow:**
   - **Automated Processes:** Platforms like Appcircle automate the distribution process, saving time and reducing manual effort.
   - **Seamless Integration:** Integrates smoothly with existing DevOps pipelines, enabling efficient build and distribution workflows.
3. **Enhanced Security:**
   - **Controlled Access:** Set specific permissions for who can access the test builds using enterprise authentication methods such as LDAP & SSO.
   - **Confidentiality:** Ensures that only authorized testers have access to the builds, protecting sensitive information.
4. **Efficient Resource Management:**
   - **Targeted Testing:** Allows the creation of specific test groups, ensuring that the right people are testing the right features.
   - **Optimized Testing:** Helps in allocating resources effectively, leading to better utilization of testing resources.
5. **Reduced Time to Market:**
   - **Eliminates Approval Delays:** By bypassing store approval processes, developers can distribute builds directly to testers, speeding up the testing cycle.
   - **Continuous Delivery:** Supports continuous delivery practices, enabling faster iterations and quicker releases.
6. **Faster Feedback Loop:**
   - **Quick Issue Identification:** Distributing test builds quickly allows developers to gather immediate feedback, identify bugs, and address issues early in the development cycle.
   - **Improved Quality:** Continuous testing helps ensure the software meets quality standards before release, reducing the likelihood of post-release issues.
7. **Cost-Effective:**
   - **Reduced Overheads:** Automating the distribution reduces the need for manual intervention, cutting down operational costs.
   - **Efficient Bug Fixes:** Early detection and fixing of bugs prevent costly fixes later in the development process.
8. **Enhanced User Experience:**
   - **Better Quality Control:** Ensures that end users receive a more stable and polished product.
   - **Customer Satisfaction:** By delivering higher quality software, customer satisfaction and trust in the product increase.

Overall, using testing distribution in mobile DevOps significantly enhances the efficiency, security, and effectiveness of the software development process, leading to better products and faster delivery times.

<!-- ## Testing Distribution

In order to share your builds with testers, you can create testing distribution profiles and assign testing groups to the profiles.

![Testing Distribution Profile](<https://cdn.appcircle.io/docs/assets/image%20(152).png>)

## Generating/Managing the Personal API Tokens

To generate a Personal API Token, follow these steps:

1. Go to the My Organization screen (the second option at the bottom left).
2. You'll find the Personal API Token section in the top right corner.
3. Press the "Generate Token" button to generate your first token.

![Token Generation](<https://cdn.appcircle.io/docs/assets/image%20(164).png>) -->

## Getting Started with the Extension: Usage Guide

To share your builds with testers, you can create testing distribution profiles and assign testing groups to these profiles.

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-appcircle_testing_distribution`, add it to your project by running:

```bash
fastlane add_plugin appcircle_testing_distribution
```

```ruby
  appcircle_testing_distribution(
    personalAPIToken: ENV["AC_PERSONAL_API_TOKEN"],
    subOrganizationName: ENV["AC_SUB_ORGANIZATION_NAME"],
    profileName: ENV["AC_PROFILE_NAME"],
    createProfileIfNotExists: ENV["AC_CREATE_PROFILE_IF_NOT_EXISTS"],
    profileCreationSettings: {
      authType: ENV["AC_PROFILE_AUTH_TYPE"],
      username: ENV["AC_PROFILE_USERNAME"],
      password: ENV["AC_PROFILE_PASSWORD"],
      testingGroupNames: ENV["AC_PROFILE_TESTING_GROUP_NAMES"]
    },
    appPath: ENV["AC_APP_PATH"],
    message: ENV["AC_MESSAGE"]
  )
```

- `personalAPIToken`: The Appcircle Personal API token used to authenticate and authorize access to Appcircle services within this plugin.
- `subOrganizationName` (optional): Required when the Root Organization's `personalAPIToken` is used, and you want to create the profile under a sub-organization. In this case, provide the name of the sub-organization in this field. If you directly used the sub-organization's `personalAPIToken`, this parameter is not needed.
- `profileName`: Specifies the profile that will be used for uploading the app.
- `createProfileIfNotExists` (optional): Ensures that a testing distribution profile is automatically created if it does not already exist; if the profile name already exists, the app will be uploaded to that existing profile instead.
- `profileCreationSettings` (optional): If `createProfileIfNotExists` is `true` and a new profile being created, the profile will be configured with these settings.
  - `authType`: Authentication type of the profile. `none`: None, `static`: Static Username and Password, `ldap`: LDAP Login, `sso`: SSO Login.
  - `username`: The username for the profile if authentication type set to `static` (Static Username and Password).
  - `password`: The password for the profile if authentication type set to `static` (Static Username and Password).
  - `testingGroupNames`: Uploaded versions will be automatically shared with these testing groups. Example format: `group1, group2, group3`.
- `appPath`: Indicates the file path to the application package that will be uploaded to Appcircle Testing Distribution Profile.
- `message`: Your message to testers, ensuring they receive important updates and information regarding the application.

## Further Details

For more information please refer to the documentation.

- [Setting Up Appcircle Testing Distribution Plugin](https://docs.appcircle.io/marketplace/fastlane/testing-distribution)
  - [Discover Action](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#discover-action)
  - [System Requirements](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#system-requirements)
  - [User Permission Requirements](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#user-permission-requirements)
  - [How to Add the Appcircle Distribute Action to Your Pipeline](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#how-to-add-the-appcircle-distribute-action-to-your-pipeline)
  - [Distributing to Sub-Organizations](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#distributing-to-sub-organizations)
  - [Leveraging Environment Variables](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#leveraging-environment-variables)
- [References](https://docs.appcircle.io/marketplace/fastlane/testing-distribution#references)

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

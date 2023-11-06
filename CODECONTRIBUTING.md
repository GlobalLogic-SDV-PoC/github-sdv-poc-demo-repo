# Contributing to SDV Code Repository
To make contributing to this project as easy and transparent as possible,
whether it's:
- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer


## Rules or best practices to follow
- **Clearly Define Module Boundaries:** Each module should have a well-defined,
  single responsibility. This promotes high cohesion and low coupling.
- **Manage Dependencies Carefully:** Try to minimize dependencies between
  modules. If using shared libraries, manage versions carefully to avoid
  conflicts. Static linking might be preferable.
- **Maximize Module Isolation:** Ensure each module is isolated and independent,
  with no shared state or data. This helps to prevent unforeseen side effects
  between modules.
- **Establish and Maintain Interface Contracts:** Define clear interfaces
  between modules, including data types and structures. Ensure all modules
  adhere to these contracts.
- **Test Each Module Thoroughly:** Each module should have its own suite of
  tests, ensuring it functions correctly in isolation. This is in addition to
  integration and end-to-end testing.
- **Avoid Global Variables:** Instead of using global variables for data
  sharing, prefer well-defined interfaces for explicit data exchange.
- **Implement Proper Versioning:** Use a versioning strategy like semantic
  versioning to track changes in each module, which will make it easier to
  understand which module versions work together.
- **Maintain Code Readability and Documentation:** Well-documented and readable
  code is important for maintenance and understanding the function of each
  module.

By following these rules, you can enhance the efficiency and maintainability
of your modular software development process.


## Repository Isolation
Each repository should be **isolated** from others, focusing on component
development rather than specific Edge-oriented development. This isolation
fosters code modularity and better management of dependencies.


## Platform-Dependent Code
Platform-dependent code must be **well-abstracted**, allowing for effective mocking
in the test environment. For example, if you need to operate with a video
stream, avoid direct communication with the driver. Instead, implement a
separate library with a platform-independent API.


## Mock Implementations
Each repository should **include mock implementations** for use in the test
environment. This practice facilitates testing by simulating specific
behaviors of software components and improves the efficiency of the testing
process.


## Strict Assembly Rules
Strict assembly rules should be enforced as much as possible to maintain high
code standards.
For C/CPP, use the following flags: **-Werror -Wall -Wextra -Wpedantic**.


## Dependencies Management
In case of a dependency on other repositories, include them as
**git submodules**. This ensures all dependent code is readily available
and that the dependencies are correctly versioned.


## Repository Structure
Your repository should follow the structure outlined below to ensure
a consistent and predictable organization:
```
<Repository Name>/
├── src/
├── include/
│   ├── <namespace name>/
├── doc/
├── dep/
│   ├── external/
│   ├── internal/
├── test/
│   ├── mock/
│   ├── unit/
│   ├── integration/
│   ├── system/
├── <Code Style Configuration Files>
├── <Build Files>
├── .git/
├── .gitignore
├── README.md
├── CONTRIBUTING.md
└── VERSION
```


## Write bug reports with detail, background, and sample code
**Great Bug Reports** tend to have:
- A quick summary and/or background.
- Steps to reproduce:
  - Be specific!
  - Include sample code that *anyone* with a base setup can run to reproduce
    the issue.
- What you expected would happen.
- What actually happens.
- Notes (possibly including why you think this might be happening, or stuff
  you tried that didn't work).


## Use a Consistent Coding Style
**TODO:** Fill in the section with the description of the code style used in a
project and preferred by the maintainer.


## Conclusion
Please adhere to these guidelines while contributing to this repository.
It ensures a smoother collaboration and efficient project development.
Thank you for your cooperation and contributions!

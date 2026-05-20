How to Run

1. Ensure the java, kotlin, and golang directories, along with "run.sh", are in the same parent directory.

   The script defaults to using numbers.txt in the root directory.

    You can also create your own file with integers, one per line.

 
3.  Make "run.sh" Executable:

    ```bash

    chmod +x run.sh

    ```

4.  Run the Script:

     To use the default "numbers.txt":

        ```bash

        ./run.sh

        ```

     To specify a different input file:

        ```bash

        ./run.sh /path/to/your/input_file.txt

        ```

The script should then compile each language's code, run both the single-threaded and multi-threaded versions, and print the results for comparison.

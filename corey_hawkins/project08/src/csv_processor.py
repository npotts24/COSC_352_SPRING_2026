import pandas as pd

def load_csv_data(filepath: str) -> pd.DataFrame:

    """

    Loads data from a CSV file into a pandas DataFrame.

    Args:

        filepath (str): The path to the CSV file.

    Returns:

        pd.DataFrame: A DataFrame containing the data from the CSV.

    """

    try:

        df = pd.read_csv(filepath)

        print(f"Successfully loaded data from: {filepath}")

        return df

    except FileNotFoundError:

        print(f"Error: File not found at {filepath}")

        return pd.DataFrame() # Return empty DataFrame on error

    except Exception as e:

        print(f"An error occurred while loading {filepath}: {e}")

        return pd.DataFrame()

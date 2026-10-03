def prune_empty(dataframe):
    
    return dataframe

def aggregate_data(dataframe):
    
    return dataframe


def transformation_pipeline(dataframe, transformations=[prune_empty, aggregate_data]):
    
    for transformation in transformations:
        dataframe = transformation(dataframe)
    
    return dataframe

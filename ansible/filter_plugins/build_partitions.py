class FilterModule(object):
    def filters(self):
        return {
            'build_partitions': self.build_partitions_filter,
        }

    def build_partitions_filter(self, partitions, storage_amt):
        """
        Builds the start and end indices for each partition
        with 1 MiB alignment.
        """
        running_total = 0
        result = []

        print(partitions)
        print(storage_amt)

        total_storage = int(storage_amt)

        for i, partition in enumerate(partitions):
            print(partition)
            new_partition = partition.copy()

            percentage = new_partition['percentage'] / 100.0

            partition_amt = int(float(percentage) * total_storage)
            running_total += partition_amt

            new_partition['size'] = partition_amt

            if i == len(partitions) - 1:
                remaining_amt = total_storage - running_total
                new_partition['size'] = partition_amt + remaining_amt

            result.append(new_partition)

        print("Original total storage:", total_storage)
        print("Running total:", sum(p['size'] for p in result))

        return result
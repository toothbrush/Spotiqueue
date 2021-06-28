//
//  PublishersExtensions.swift
//  Spotiqueue
//
//  Created by paul david on 28/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Combine

// This was after a whole adventure.  Finally found an answer at https://stackoverflow.com/questions/56782078/swift-combine-how-to-create-a-single-publisher-from-a-list-of-publishers
extension Publishers {

    private struct EnumeratedElement<T> {
        let index: Int
        let element: T

        init(index: Int, element: T) {
            self.index = index
            self.element = element
        }

        init(_ enumeratedSequence: EnumeratedSequence<[T]>.Iterator.Element) {
            index = enumeratedSequence.offset
            element = enumeratedSequence.element
        }
    }

    static func mergeMappedRetainingOrder<InputType, OutputType>(
        _ inputArray: [InputType],
        mapTransform: (InputType) -> AnyPublisher<OutputType, Error>
    ) -> AnyPublisher<[OutputType], Error> {

        let enumeratedInputArray = inputArray.enumerated().map(EnumeratedElement.init)

        let enumeratedMapTransform: (EnumeratedElement<InputType>) -> AnyPublisher<EnumeratedElement<OutputType>, Error> = { enumeratedInput in
            mapTransform(enumeratedInput.element)
                .map { EnumeratedElement(index: enumeratedInput.index, element: $0)}
                .eraseToAnyPublisher()
        }

        let sortEnumeratedOutputArrayByIndex: ([EnumeratedElement<OutputType>]) -> [EnumeratedElement<OutputType>] = { enumeratedOutputArray in
            enumeratedOutputArray.sorted { $0.index < $1.index }
        }

        let transformToNonEnumeratedArray: ([EnumeratedElement<OutputType>]) -> [OutputType] = {
            $0.map { $0.element }
        }

        return Publishers.MergeMany(enumeratedInputArray.map(enumeratedMapTransform))
            .collect()
            .map(sortEnumeratedOutputArrayByIndex)
            .map(transformToNonEnumeratedArray)
            .eraseToAnyPublisher()
    }
}
